# Scarlett MIDI Control — agent notes

Menu-bar client for **classic** Focusrite Control Server and a live **Scarlett 18i20 (2nd Gen)**. Not Control 2.

Repo: `https://origin.cursor.com/catkins/scarlett-midi-remote.git` (`origin` only). **Never replace the origin remote.** No GitHub remote. CI is Buildkite org `catkins-test`, pipeline `scarlett-midi-remote`, queue `hosted-macos`.

## Run / verify
- App: `./scripts/run-local.sh` then click the menu-bar **fader** icon (`slider.vertical.3`)
- Snapshot (no click required): `./scripts/snapshot-ui.sh` → `.build/snapshots/mixer.png` (read that PNG)
- Tests: `swift test` needs full Xcode. This Mac often has Command Line Tools only; CI is the real runner
- Lint+test helper: `./scripts/ci.sh`

## After every visual change
`run-local.sh` kills the previous `ScarlettMidiControl` and opens the new bundle. An already-running process keeps the old UI and the old CPU path — **do not skip the relaunch**.
1. `./scripts/run-local.sh`
2. `./scripts/snapshot-ui.sh`
3. Read `.build/snapshots/mixer.png` and check the thing you changed (and nearby chrome)
4. Do not call the UI done until you have looked at that PNG
If the live panel is open, glance at that too — the snapshot fixture can differ from the connected mixer.

## Protocol (verified live)
- Frames: `Length=<6 hex> ` + UTF-8 XML, header-only, concatenated. Do not invent a footer.
- Parse IDs from `<device-arrival>`. **Do not hardcode** parameter IDs.
- Writes: `<set devid="1"><item id="…" value="…"/></set>`
- Client must be approved in Focusrite Control → Settings → Remote Devices
- Snapshot omits false/empty items (mute/solo/source)
- Mixer: 18 slots; Mix A–E each L/R. Output `source` value **is the mix id**
- Stereo slot: one fader writes both slot indices **and** the partner R mix
- Hardware monitor: use hardware gain/mute IDs, **not** analogue Monitor L/R software gains (sliders fight). Suppress inbound echoes ~0.75s on IDs just written

## UI rules
- `MenuBarExtra` `.window` style. **Do not wrap the whole popover in a ScrollView** (height collapses). Mix strips can scroll internally if they overflow. Glass should match a native menu extra: `.menu` material, clear host window, no stacked frosts. Follow system light/dark — do not force `darkAqua`. Selected output is a translucent wash, not a solid chip. Snapshot captures a real window (ImageRenderer cannot show vibrancy).
- Settings and MIDI live in the footer **gear** / **piano-keys** controls — not always-visible sections. Status, Disconnect, and **Quit** share that footer row.
- Output switching is a split-button / segmented control, **3 per row**. Extra rows join the same rounded control (hairline between rows), not separate pills.
- MIDI Learn: piano-keys arms; click a control; next CC/note maps. Masters are per output; strips are `strip:{mixId}:{slot}:{gain|mute|solo}`
- Mix strips only appear after connect + approval + snapshot fills slot sources. Separate hardware / playback with a hairline, not ALL-CAPS section titles. 1-based slot numbers sit small and muted to the left of the name (`1/2` when stereo).
- Per-strip VU uses the source `<meter>` (dBFS, −128 silence). Output row uses the output meter. Keep meters quiet — thin bar, no clip fireworks.

## CI pitfalls
- Hosted cache keys must not contain `{{ checksum … }}` (interpolation parse error). Use `$BUILDKITE_COMMIT`.
- Do not put `{{testExamples}}` in `.buildkite/pipeline.yml` (same interpolation). File splitting is optional; `./scripts/ci.sh test` maps `*.swift` args to `--filter`.
- Test step is `bktec run` with `tests#v1.0.0` (`test-runner: custom`, JUnit at `tmp/swift-test-results.xml`). Use `--xunit-output=path` (equals) or Swift writes `*-swift-testing.xml` instead.
- App artifact: `./scripts/ci.sh build` → `tmp/ScarlettMidiControl.app.zip` (`artifact_paths` on the App step).
- `Package.swift` is tools 6.0, language mode v5, test targets v6 so `import Testing` works on Xcode agents
- `gh` GitHub auth may be stale; use Origin + Buildkite APIs instead

## Do not
- Copy proprietary Focusrite source
- Map MIDI only to monitor — learn is per output and per mix strip
- Dual-write analogue monitor channel gains and hardware monitor
- Change `origin` to GitHub “for CI”
