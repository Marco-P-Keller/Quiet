// Photograph a page frame by frame, in Chrome, and hand the frames to ffmpeg.
//
//     node Tools/render-page.mjs <page.html?query> <out.mp4> [--scale 2] [--samples 12]
//                                [--from 0] [--to <seconds>] [--stills 1.0,2.5,...]
//                                [--viewport 1080x2340] [--size 886x1920] [--png]
//
// No dependency: Chrome is the one already on the machine, spoken to over the
// DevTools protocol with the WebSocket that Node has built in. The page owns
// time — it exposes `seek(t)` and `DURATION` — so every frame is exactly the
// frame it should be, however long a screenshot takes.
//
// Motion blur is real: each output frame is the average of several moments
// across half a frame (a 180° shutter, what a film camera has), blended by
// ffmpeg's `tmix`. A whip pan photographed at one instant is a strobe; the
// same pan averaged over its shutter is a movement.
//
// And it is spent where it is needed. Four samples across a whip pan are four
// sharp phones, not one moving one — the gap between samples has to be smaller
// than the blur it is building. So the page says, through `SAMPLES(t)`, how
// many moments each frame deserves: one for a hold, a dozen for a whip. ffmpeg
// always averages `--samples` buffers; a frame that needs fewer repeats each
// of its photographs to fill them, which costs a pipe write, not a screenshot.

import { spawn } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const FPS = 30;

const args = process.argv.slice(2);
const option = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : fallback;
};
// `--png` takes no value: stills come out lossless, for screenshots that are
// uploaded as they are rather than cut into a film.
const FLAGS = ["--png"];
const [pageArg, outArg] = args.filter((a, i) => !a.startsWith("--") &&
  (!(args[i - 1] || "").startsWith("--") || FLAGS.includes(args[i - 1])));
const scale = Number(option("scale", 2));
const samples = Number(option("samples", 12));
const stills = option("stills", null);
const png = args.includes("--png");
// The page's own size, and the film's. The App Store preview is laid out on
// 1080 x 2340 and delivered at 886 x 1920; everything else is 1080 x 1920 both.
const [W, H] = option("viewport", "1080x1920").split("x").map(Number);
const [OW, OH] = option("size", `${W}x${H}`).split("x").map(Number);

const [pagePath, query = ""] = pageArg.split("?");
const url = pathToFileURL(resolve(pagePath)).href + (query ? `?${query}` : "");

const profile = mkdtempSync(join(tmpdir(), "quiet-render-"));
const chrome = spawn(CHROME, [
  "--headless=new", "--remote-debugging-port=0", `--user-data-dir=${profile}`,
  "--hide-scrollbars", "--force-color-profile=srgb", "--disable-lcd-text",
  "--allow-file-access-from-files", "--no-first-run", "--no-default-browser-check",
  "--disable-background-timer-throttling", "--disable-renderer-backgrounding",
  "about:blank",
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
await page("Emulation.setDeviceMetricsOverride", { width: W, height: H, deviceScaleFactor: scale, mobile: false });
const loaded = new Promise((ok) => listeners.push((m) => m.method === "Page.loadEventFired" && ok()));
await page("Page.navigate", { url });
await loaded;

const evaluate = async (expression) => {
  const r = await page("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
  if (r.exceptionDetails) throw new Error(JSON.stringify(r.exceptionDetails, null, 1));
  return r.result.value;
};
page("Runtime.consoleAPICalled").catch(() => {});
listeners.push((m) => {
  if (m.method === "Runtime.consoleAPICalled") console.log("  page:", m.params.args.map((a) => a.value).join(" "));
});

await evaluate("window.ready");
const duration = await evaluate("DURATION");
const cues = await evaluate("JSON.stringify(window.CUES || [])");
writeFileSync(outArg.replace(/\.[a-z0-9]+$/, "") + ".cues.json", cues);

const probe = option("probe", null);
if (probe) console.log(JSON.stringify(await evaluate(probe), null, 1));

const shoot = async (t) => {
  await evaluate(`seek(${t}); new Promise(r => requestAnimationFrame(() => requestAnimationFrame(() => requestAnimationFrame(r))))`);
  const { data } = await page("Page.captureScreenshot",
    png ? { format: "png" } : { format: "jpeg", quality: 94, optimizeForSpeed: true });
  return Buffer.from(data, "base64");
};

if (stills) {
  const times = stills.split(",").map(Number);
  const base = outArg.replace(/\.[a-z0-9]+$/, "");
  for (const t of times) {
    writeFileSync(`${base}-${t.toFixed(2)}.${png ? "png" : "jpg"}`, await shoot(t));
  }
  console.log(`  ${times.length} stills`);
} else {
  const from = Number(option("from", 0));
  const to = Math.min(Number(option("to", duration)), duration);
  const frames = Math.round((to - from) * FPS);
  const shutter = 0.5 / FPS;
  const ffmpeg = spawn("ffmpeg", [
    "-y", "-loglevel", "error",
    "-f", "image2pipe", "-framerate", String(FPS * samples), "-c:v", "mjpeg", "-i", "-",
    "-vf", [
      samples > 1 ? `tmix=frames=${samples}` : null,
      samples > 1 ? `select='eq(mod(n\\,${samples})\\,${samples - 1})'` : null,
      `setpts=N/${FPS}/TB`,
      `scale=${OW}:${OH}:flags=lanczos`,
    ].filter(Boolean).join(","),
    "-r", String(FPS), "-c:v", "libx264", "-preset", "slow", "-crf", "12",
    "-pix_fmt", "yuv420p", outArg,
  ], { stdio: ["pipe", "inherit", "inherit"] });
  const started = Date.now();
  const divisors = [...Array(samples).keys()].map((i) => i + 1).filter((d) => samples % d === 0);
  let shots = 0;
  for (let n = 0; n < frames; n++) {
    const at = from + n / FPS;
    const asked = await evaluate(`typeof SAMPLES === "function" ? SAMPLES(${at}) : ${samples}`);
    const k = divisors.find((d) => d >= asked) ?? samples;
    for (let j = 0; j < k; j++) {
      const t = at + (k > 1 ? (j / (k - 1) - 0.5) * shutter : 0);
      const jpeg = await shoot(Math.max(0, t));
      shots++;
      for (let r = 0; r < samples / k; r++) {
        if (!ffmpeg.stdin.write(jpeg)) await new Promise((ok) => ffmpeg.stdin.once("drain", ok));
      }
    }
    if (n % 60 === 0) {
      const rate = (Date.now() - started) / Math.max(1, n) / 1000;
      console.log(`  ${n}/${frames}  ${shots} photographs  ~${Math.round(rate * (frames - n))}s left`);
    }
  }
  ffmpeg.stdin.end();
  await new Promise((ok) => ffmpeg.on("exit", ok));
}

socket.close();
const gone = new Promise((ok) => chrome.on("exit", ok));
chrome.kill();
await gone;
try { rmSync(profile, { recursive: true, force: true }); } catch {}
