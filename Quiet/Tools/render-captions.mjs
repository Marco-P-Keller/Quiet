// Photograph a list of caption pages in Chrome, transparent, one PNG each.
//
//     node Tools/render-captions.mjs <jobs.json>
//
// `jobs.json` is a list of `{ "html": "<path>", "png": "<path>" }`. Every page
// is 1320 x 2868 with nothing behind its text, so the PNG can be laid over a
// finished slide. `make-shots.py` writes the pages and the jobs and reads the
// PNGs back; this is only the camera.
//
// It exists because Pillow here has no text shaping. Arabic arrives unjoined,
// Hebrew back to front, Hindi and Thai with their marks adrift, and Chrome is
// the one thing on this machine that sets all of them correctly. Each page says
// where its text ended through `window.RESULT`, which is printed one JSON line
// per page for the caller to check against the phone below it.
//
// No dependency: the same DevTools-over-WebSocket as `render-page.mjs`.

import { spawn } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const jobs = JSON.parse(readFileSync(process.argv[2], "utf8"));

const profile = mkdtempSync(`${tmpdir()}/quiet-captions-`);
const chrome = spawn(CHROME, [
  "--headless=new", "--remote-debugging-port=0", `--user-data-dir=${profile}`,
  "--hide-scrollbars", "--force-color-profile=srgb", "--allow-file-access-from-files",
  "--no-first-run", "--no-default-browser-check", "about:blank",
], { stdio: ["ignore", "ignore", "pipe"] });

const endpoint = await new Promise((ok, fail) => {
  let seen = "";
  chrome.stderr.on("data", (chunk) => {
    seen += chunk;
    const m = seen.match(/DevTools listening on (ws:\/\/\S+)/);
    if (m) ok(m[1]);
  });
  chrome.on("exit", () => fail(new Error("Chrome exited:\n" + seen)));
});

const socket = new WebSocket(endpoint);
await new Promise((ok) => socket.addEventListener("open", ok, { once: true }));
let nextId = 1;
const pending = new Map();
const listeners = [];
socket.addEventListener("message", (event) => {
  const msg = JSON.parse(event.data);
  if (msg.id && pending.has(msg.id)) {
    const { ok, fail } = pending.get(msg.id);
    pending.delete(msg.id);
    msg.error ? fail(new Error(JSON.stringify(msg.error))) : ok(msg.result);
  } else if (msg.method) {
    listeners.forEach((l) => l(msg));
  }
});
const send = (method, params = {}, sessionId) => new Promise((ok, fail) => {
  const id = nextId++;
  pending.set(id, { ok, fail });
  socket.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
});

const { targetId } = await send("Target.createTarget", { url: "about:blank" });
const { sessionId } = await send("Target.attachToTarget", { targetId, flatten: true });
const page = (method, params) => send(method, params, sessionId);

await page("Page.enable");
await page("Runtime.enable");
await page("Emulation.setDeviceMetricsOverride", { width: 1320, height: 2868, deviceScaleFactor: 1, mobile: false });
await page("Emulation.setDefaultBackgroundColorOverride", { color: { r: 0, g: 0, b: 0, a: 0 } });

for (const job of jobs) {
  const loaded = new Promise((ok) => listeners.push((m) => m.method === "Page.loadEventFired" && ok()));
  await page("Page.navigate", { url: pathToFileURL(resolve(job.html)).href });
  await loaded;
  const r = await page("Runtime.evaluate", {
    expression: "document.fonts.ready.then(() => window.fit()).then(() => JSON.stringify(window.RESULT))",
    awaitPromise: true, returnByValue: true,
  });
  if (r.exceptionDetails) throw new Error(job.html + ": " + JSON.stringify(r.exceptionDetails));
  const { data } = await page("Page.captureScreenshot", { format: "png", fromSurface: true });
  writeFileSync(job.png, Buffer.from(data, "base64"));
  console.log(JSON.stringify({ png: job.png, ...JSON.parse(r.result.value) }));
}

socket.close();
const gone = new Promise((ok) => chrome.on("exit", ok));
chrome.kill();
await gone;
try { rmSync(profile, { recursive: true, force: true }); } catch {}
