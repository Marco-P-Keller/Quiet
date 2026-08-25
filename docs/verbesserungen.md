# Verbesserungen — Stand

Die 38 Punkte aus der Durchsicht vom 25. August 2026, mit dem, was daraus
geworden ist. Auf Deutsch, weil die Liste aus einem deutschen Gespräch kommt;
die vier Dokumente daneben bleiben Englisch.

**Legende**

| | |
|---|---|
| ✅ | eingebaut und geprüft |
| 🔧 | angefangen, noch nicht fertig |
| ⏸ | bewusst nicht gemacht — Begründung dabei |
| 👤 | braucht einen Menschen: ein echtes Telefon, einen Übersetzer, eine Produktentscheidung |

---

## 1. Das Kernversprechen

| # | Punkt | Stand | Wo |
|---|---|---|---|
| 1 | Uhr vorstellen war der offene Ausweg | ✅ | `Core/TimeAnchor.swift`, `Core/TimeSource.swift` |
| 2 | Zurückgenommene Erhöhung verbraucht die Woche unsichtbar | ⬜ | Panel/LimitView |
| 3 | DMs kosten Limit wie Scrollen — ungeschriebene Entscheidung | ⬜ | `docs/decisions.md` |
| 4 | Warnschwellen 5/1 sind hart und nicht abschaltbar | ⬜ | `Core/RowShape.swift` (Preferences), Panel |
| 5 | Cooldown fest auf 7 Tage | ⬜ | `Core/LimitPolicy.swift`, Setup |
| 6 | Kein Sync, kein Backup | ⏸ | Braucht einen Server. Steht in den Trade-offs. |
| 7 | Kein ehrlicher Ausstieg („Quiet vergessen") | ⬜ | Panel |
| 8 | `isWritable` heilte nie | ✅ | `Platform/KeychainStore.swift` |
| 9 | Die Stunde stand zweimal im Code | ✅ | `Core/Elapsed.swift` |

**Zu 1:** Der `Date:`-Header jeder Instagram-Antwort ist der Anker, gepaart mit
`systemUptime`. Kein Server, keine eigene Anfrage. Repariert nebenbei den Fall,
in dem eine Uhr vor- und zurückgestellt die App wochenlang einfror.

## 2. Die Instagram-Schicht

| # | Punkt | Stand | Wo |
|---|---|---|---|
| 10 | Nur 8 Sprachen, harte Strings | ✅ | `Web/trim.js` — jetzt 47 Phrasen, 24 Sprachen |
| 11 | Kein Selbsttest, ob das Trimmen noch greift | ⬜ | `Web/trim.js`, Panel |
| 12 | `WKContentRuleList` ungenutzt | ⬜ | neue Datei neben `WebScripts.swift` |
| 13 | `navRow()` ist eine Heuristik ohne Fixtures | 🔧 | Harness steht, Fixtures fehlen |
| 14 | `internalDomains` hat nur 5 Einträge | ✅ | anders gelöst als vorgeschlagen — siehe unten |
| 15 | `/tv/` fehlte in `blockedRoots` | ✅ | `Core/ContentRules.swift`, `Web/trim.js` |
| 16 | Reels im Chat werden zu drei Toasts | ⬜ | `Web/trim.js` |
| 17 | Suche kennt keine zuletzt besuchten Profile | ⬜ | `UI/SearchView.swift` |

**Zu 10:** Beim Schreiben der Liste kam heraus, dass Türkisch mit der alten
Vergleichslogik *nie* hätte greifen können: `"İ".toLowerCase()` ist nicht `"i"`,
sondern `i` plus kombinierender Punkt. Dazu kommen Instagrams geschützte
Leerzeichen und zwei Schreibweisen für jeden Akzent. Der Vergleich normalisiert
jetzt (NFKD, Kombinationszeichen weg, Leerraum zusammengezogen) — drei Fallen
auf einmal, jede mit einem eigenen Test.

**Zu 14:** Die Allowlist lässt sich nicht durch Raten vervollständigen — das ist
der Sinn einer Allowlist. Vervollständigen lässt sich die *Erklärung*: eine
Weitergabe an Safari mitten im Login nennt jetzt die Adresse und wird gemerkt,
damit aus „ich kann mich nicht anmelden" ein Hostname wird.

**Zu 15:** `/s/` habe ich bewusst *nicht* blockiert — das sind geteilte
Story-Links, und die zu sperren würde eine Funktion kaputtmachen, die bleiben
soll.

## 3. iOS-Plattform

| # | Punkt | Stand | Wo |
|---|---|---|---|
| 18 | Kamera-/Mikrofon-/Foto-Strings fehlten (Absturzrisiko) | ✅ | `Info.plist`, `Resources/InfoPlist.xcstrings` |
| 19 | Skripte laufen in Instagrams eigener JS-Welt | ⬜ | Abwägung offen — siehe unten |
| 20 | Keine App-Intents / Shortcuts | ⬜ | |
| 21 | Kein Widget | 👤 | Neues Target, App Group, Keychain-Sharing |
| 22 | Keine Benachrichtigungen → man öffnet öfter „nur kurz" | ⏸ | Ohne Server und im Web-Client nicht möglich |
| 23 | Kein eigener Offline-Zustand | ⬜ | `UI/BrowserScreen.swift` |
| 24 | Website-Daten wachsen unbegrenzt | ⬜ | Panel |
| 25 | iPad/Landscape nirgends dokumentiert | ⬜ | Im Code längst entschieden, nur nicht aufgeschrieben |
| 26 | Bold Text / Kontrast ungeprüft | ⬜ | `UI/Design.swift` |
| 27 | Restzeit für VoiceOver nur über das Panel | ⬜ | `UI/BrowserScreen.swift` |

**Zu 19:** Die Abwägung ist echt und nicht eindeutig. `trim.js` muss
`history.pushState` überschreiben, um Instagrams eigene Navigation zu bemerken —
und genau das funktioniert aus einer isolierten Welt heraus *nicht*. Der
Sicherheitsgewinn ist gleichzeitig klein: eine gefälschte Nachricht der Seite
könnte einen Toast auslösen oder das falsche Symbol markieren, aber nichts am
Limit ändern. Plan: den Handler isolieren und nur die eine
History-Beobachtung als winziges Shim in der Seitenwelt lassen, das per
DOM-Event hinüberruft.

## 4. Produkt und Store

| # | Punkt | Stand | Wo |
|---|---|---|---|
| 28 | Nur Englisch und Deutsch | 👤 | Ein Übersetzer, kein Skript — siehe unten |
| 29 | Ein-Stern-Risiko: „Reels fehlen, App kaputt" | ⬜ | `UI/SetupView.swift` |
| 30 | Keychain-Verhalten nur im Setup erklärt | ✅ | Stimmte nicht — das Panel sagt es bereits |
| 31 | Start-URL ohne Fallback | ⬜ | `Core/ContentRules.swift` |

**Zu 28:** Ich baue das nicht maschinell ein. Der ganze Wert dieser App steckt
in ihren Sätzen; 77 davon durch eine Übersetzung zu drehen, die niemand
gegenliest, macht die App in vier Sprachen schlechter statt in vier Sprachen
verfügbar. Die Infrastruktur steht (Katalog, Plurale, Screenshots pro Sprache) —
es fehlt ein Mensch pro Sprache.

**Zu 30:** Beim Nachlesen war der Punkt falsch. `PanelView` trägt den Satz
bereits: „Your limit is kept in the keychain, which outlives the app."

## 5. Code, Tests, CI

| # | Punkt | Stand | Wo |
|---|---|---|---|
| 32 | Zwei Dateien tragen ein Drittel des Codes | ⬜ | `Web/InstagramWebView.swift`, `UI/BrowserScreen.swift` |
| 33 | `trim.js` hatte keinen einzigen Test | ✅ | `Tools/read-the-trim.js`, `Tools/page.js`, CI-Job |
| 34 | Screenshots sind Artefakte, keine Prüfungen | ⬜ | `.github/workflows/screenshots.yml` |
| 35 | `Timer` statt injizierbarem Zeitgeber | ⬜ | `Session/QuietSession.swift` |
| 36 | Kein Lint / Format in CI | ⬜ | `.github/workflows/quiet.yml` |
| 37 | Keine Vollständigkeitsprüfung des String-Katalogs | ⬜ | neues Tool + CI |
| 38 | Keine Performance-Grundlinie | ⬜ | |

**Zu 33:** 47 Prüfungen auf einer jsdom-Seite, die nicht Instagram gehört —
blockierte Pfade, Profile die nur so *aussehen*, Vorschlagsblöcke, jede einzelne
Phrase der Liste, recycelte DOM-Knoten, und Navigation ohne Seitenladen. Läuft
auf Linux in Sekunden, vor dem macOS-Job.

---

## Nebenbei gefunden

Nicht Teil der 38, aber beim Bauen aufgefallen:

* **`docs/what-is-left.md` §2.2 stimmt nicht.** Es behauptet, Datenschutz- und
  Support-Seite lägen in `site/` und würden von einem Workflow nach `gh-pages`
  veröffentlicht. Beides existiert nicht — es gibt weder `site/` noch einen
  Pages-Workflow, und die `privacy.html` im Wurzelverzeichnis gehört zu einer
  anderen App. ⬜
* **`surfaceFor` in `trim.js` hätte sich verrechnet.** Es leitete die Fläche aus
  der Schreibweise ab („beginnt mit reel"), was für vier Einträge stimmte. `tv`
  hätte sich als Explore gemeldet. Jetzt eine Tabelle. ✅

---

## Was zuerst

1. **11 + 12** — Selbstdiagnose und Content-Blocker. Zusammen schließen sie die
   Lücke, die dieses ganze Konzept hat: eine Ebene, die Instagram nicht durch
   Umbenennen aushebeln kann, und eine Stimme für den Fall, dass die andere
   Ebene doch ausfällt.
2. **2, 4, 5, 7** — die vier Panel-Punkte, ein Block.
3. **35, 36, 37** — CI, damit der Rest nicht wieder still kaputtgehen kann.
4. **23, 24, 17** — Offline, Speicher, zuletzt Besuchte.
