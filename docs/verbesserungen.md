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
| 2 | Zurückgenommene Erhöhung verbraucht die Woche unsichtbar | ✅ | `UI/LimitView.swift` |
| 3 | DMs kosten Limit wie Scrollen — ungeschriebene Entscheidung | ✅ | `docs/decisions.md` |
| 4 | Warnschwellen 5/1 sind hart und nicht abschaltbar | ✅ | `Core/RowShape.swift`, Panel |
| 5 | Cooldown fest auf 7 Tage | ✅ | `Core/LimitPolicy.swift`, Panel |
| 6 | Kein Sync, kein Backup | ⏸ | Braucht einen Server. Steht in den Trade-offs. |
| 7 | Kein ehrlicher Ausstieg | ✅ | `Session/QuietSession.swift`, Panel |
| 8 | `isWritable` heilte nie | ✅ | `Platform/KeychainStore.swift` |
| 9 | Die Stunde stand zweimal im Code | ✅ | `Core/Elapsed.swift` |

**Zu 1:** Der `Date:`-Header jeder Instagram-Antwort ist der Anker, gepaart mit
`systemUptime`. Kein Server, keine eigene Anfrage. Repariert nebenbei den Fall,
in dem eine Uhr vor- und zurückgestellt die App wochenlang einfror.

## 2. Die Instagram-Schicht

| # | Punkt | Stand | Wo |
|---|---|---|---|
| 10 | Nur 8 Sprachen, harte Strings | ✅ | `Web/trim.js` — jetzt 47 Phrasen, 24 Sprachen |
| 11 | Kein Selbsttest, ob das Trimmen noch greift | ✅ | `Web/Health.swift`, `Web/trim.js`, Panel |
| 12 | `WKContentRuleList` ungenutzt | ✅ | `Web/BlockList.swift` |
| 13 | `navRow()` ist eine Heuristik ohne Fixtures | ✅ | `Tools/read-the-trim.js` |
| 14 | `internalDomains` hat nur 5 Einträge | ✅ | anders gelöst als vorgeschlagen — siehe unten |
| 15 | `/tv/` fehlte in `blockedRoots` | ✅ | `Core/ContentRules.swift`, `Web/trim.js` |
| 16 | Reels im Chat werden zu drei Toasts | ⬜ | `Web/trim.js` |
| 17 | Suche kennt keine zuletzt besuchten Profile | ✅ | `Web/Remembered.swift`, `UI/SearchView.swift` |

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
| 20 | Keine App-Intents / Shortcuts | ⬜ | in den Trade-offs benannt |
| 21 | Kein Widget | 👤 | Neues Target, App Group, Keychain-Sharing |
| 22 | Keine Benachrichtigungen → man öffnet öfter „nur kurz" | ⏸ | Ohne Server und im Web-Client nicht möglich |
| 23 | Kein eigener Offline-Zustand | ✅ | `UI/StumbleView.swift` |
| 24 | Website-Daten wachsen unbegrenzt | ✅ | `Web/InstagramWebView.swift`, Panel |
| 25 | iPad/Landscape nirgends dokumentiert | ✅ | `docs/trade-offs.md` |
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
| 29 | Ein-Stern-Risiko: Reels fehlen | ✅ | `UI/SetupView.swift` |
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
| 35 | `Timer` statt injizierbarem Zeitgeber | ✅ | `Core/Heartbeat.swift`, `QuietTests/CountingTests.swift` |
| 36 | Kein Lint / Format in CI | ✅ | `.github/workflows/quiet.yml` |
| 37 | Keine Vollständigkeitsprüfung des String-Katalogs | ✅ | `Tools/read-the-strings.py` |
| 38 | Keine Performance-Grundlinie | ⬜ | |

**Zu 33:** 47 Prüfungen auf einer jsdom-Seite, die nicht Instagram gehört —
blockierte Pfade, Profile die nur so *aussehen*, Vorschlagsblöcke, jede einzelne
Phrase der Liste, recycelte DOM-Knoten, und Navigation ohne Seitenladen. Läuft
auf Linux in Sekunden, vor dem macOS-Job.

---

## Nebenbei gefunden

Nicht Teil der 38, aber beim Bauen aufgefallen:

* **`docs/what-is-left.md` §2.2 stimmte nicht.** ✅ Es behauptete, Datenschutz-
  und Support-Seite lägen in `site/` und würden von einem Workflow nach
  `gh-pages` veröffentlicht. Nichts davon existierte — die `privacy.html` im
  Wurzelverzeichnis gehört zu einer anderen App. Jetzt gibt es `Quiet/site/`
  (Index, Datenschutz, Support, je Englisch und Deutsch) und
  `.github/workflows/pages.yml`. Zwei Handgriffe bleiben: Pages einschalten, und
  eine echte Kontaktadresse statt des Platzhalters — der Workflow verweigert die
  Veröffentlichung, solange der Platzhalter drinsteht.
* **`surfaceFor` in `trim.js` hätte sich verrechnet.** Es leitete die Fläche aus
  der Schreibweise ab („beginnt mit reel"), was für vier Einträge stimmte. `tv`
  hätte sich als Explore gemeldet. Jetzt eine Tabelle. ✅

---

## Was noch offen ist

| # | Punkt | Warum noch nicht |
|---|---|---|
| 6 | Sync zwischen Geräten | Braucht einen Server |
| 16 | Reels im Chat still markieren statt Toast | Machbar, aber nur an einem echten Chat beurteilbar |
| 19 | Skripte in isolierter JS-Welt | Echte Abwägung, siehe oben — nicht blind zu entscheiden |
| 20 | App-Intents / Shortcuts | Möglich, nicht gebaut |
| 21 | Widget | Neues Target, App Group, Keychain-Sharing |
| 22 | Benachrichtigungen | Ohne Server unmöglich |
| 26 | Bold Text / Kontrast | Braucht ein Auge auf einem echten Gerät |
| 27 | Restzeit im VoiceOver-Rotor | Machbar, nicht gebaut |
| 28 | Weitere Sprachen | Ein Mensch pro Sprache, kein Skript |
| 31 | Fallback für die Start-URL | Machbar, nicht gebaut |
| 32 | Die zwei großen Dateien aufteilen | Reine Umstrukturierung; ohne Compiler zur Hand riskant |
| 34 | Screenshots als Prüfung statt Artefakt | Braucht eingecheckte Referenzbilder |
| 38 | Performance-Grundlinie | Machbar, nicht gebaut |

**25 von 38 eingebaut. 2 bewusst verworfen (6, 22), 2 brauchen einen
Menschen (21, 28), 9 offen.**

## Was zuerst

1. **19** — die JS-Welt, sobald jemand mit einem Telefon danebensitzt.
2. **32** — die beiden großen Dateien, sobald ein Compiler zur Hand ist.
3. **27 + 26** — Barrierefreiheit über Dynamic Type hinaus.
4. **34 + 38** — die letzten zwei CI-Löcher.
