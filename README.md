## Scarlett MIDI Control (macOS Menu Bar)

Control your Focusrite Scarlett 18i20 (2nd Gen) hardware mixer and monitor levels from a MIDI controller. This macOS menu bar app discovers and talks to the local Focusrite Control server (the classic one used by the original iOS remote), letting you map MIDI CC/notes to common controls like Monitor volume and Mute.

Status: MVP scaffold. Networking and protocol framing are implemented as stubs with clear TODOs and references. The UI, MIDI I/O, and persistence are ready to be wired up once the protocol is verified live against a running server.

### Why this exists
- Focusrite's classic Control app exposes a local "FocusriteControlServer" process that iOS remotes used to connect to.
- This project re-implements a minimal client for that legacy protocol so you can drive your interface from a MIDI controller while Focusrite Control is installed. It does not copy any proprietary Focusrite code.

### Supported devices
- Targeted first: Scarlett 18i20 (2nd Gen)
- Designed so other Gen 2 Scarletts can be added later

---

## Architecture (menu bar app)

- `FocusriteControlKit` (framework)
  - `DiscoveryService`: UDP discovery stub that models iOS client behavior (broadcast to 30096..30098). Replace stub with real UDP once you can capture replies on your Mac.
  - `ControlServerClient`: TCP client using Network.framework with keep-alive and length-prefixed XML framing. Approval and device messages are placeholders until verified.
  - `ProtocolFraming`: Encodes/decodes the classic `Length=<hex>` framing that wraps XML payloads. Footer handling is permissive during bring-up.
  - `Scarlett18i20Gen2Model`: Simple device model (monitor L/R dB, mute).
- `MidiKit` (framework)
  - `MidiManager`: CoreMIDI input from a single selected port (by UID); "MIDI learn" callback captures CC/Note events. No "listen-to-all" pitfalls.
- `PersistenceKit` (framework)
  - `SettingsStore`: UserDefaults (`@AppStorage`) for client name, auto-reconnect, selected MIDI input UID + JSON file in Application Support for mappings.
- SwiftUI Menu Bar App (`MenuBarExtra`)
  - Menu bar icon reflects connection state (disconnected / awaiting approval / connected)
  - Popover shows connection status, MIDI source picker (single selected port), primary monitor/mute controls, and per-control Learn buttons
  - Optional "Open Full Panel" stub for expanded mix strips later

---

## Protocol reference (public reverse‑engineering notes)

Treat this as guidance. Verify everything against your running `FocusriteControlServer` on macOS.

Sources:
- Focusrite-Midi-Control (Swift): `https://github.com/raduvarga/Focusrite-Midi-Control`
- UDP discovery gist: `https://gist.github.com/daveyijzermans/f0354858b3eb765e19361ab85a6bc55b`
- Node API: `https://github.com/Mathieu2301/Focusrite-Control-API`

Observed flow (classic iOS era, not Control 2):
1. Discovery via UDP broadcast: send `Length=<6hex> <client-discovery app="SAFFIRE-CONTROL" version="4" device="iOS"/>` to ports 30096, 30097, 30098. Server replies with XML that includes a TCP port (commonly near 49152).
2. Connect TCP, send client details (name + key), then periodic keep-alive (~3s).
3. Receive device description, subscribe, and wait for the user to approve this client in Focusrite Control.
4. Exchange value updates for controls/mixes.

This app ships stubs for steps 1–4. See `docs/PROTOCOL.md` for message framing and TODOs.

---

## Building locally (macOS)

Prereqs:
- macOS 13+ (Apple Silicon or Intel)
- Xcode 14+ (or newer)
- Classic Focusrite Control installed (not Control 2), so `FocusriteControlServer` runs locally
- Homebrew (for XcodeGen), optional but recommended

### Origin repository

This project is developed in a Cursor **New Project** draft (`tmp-*` name). To use a permanent repo name:

**Option A — Publish the draft (recommended)**  
In the Cursor agent run UI, use **Publish** (or equivalent) and set the repo name to `scarlett-midi-control`. Draft repos are renamed on first publish.

**Option B — Create a new repo from your Mac**  
The Cloud Agent session cannot call `origin repo create` (token scoped to the draft only). On your machine:

```bash
origin auth login
./scripts/create-origin-repo.sh
```

Or manually:

```bash
origin repo create catkins/scarlett-midi-control
git remote set-url origin https://origin.cursor.com/git/catkins/scarlett-midi-control.git
git push -u origin main
```

Current draft URL (until published): `https://origin.cursor.com/git/catkins/tmp-2dbf9251e3f2a0f2`

Steps:
1. Generate the Xcode project (we keep sources committed and generate the .xcodeproj locally):
   ```bash
   brew install xcodegen
   xcodegen generate
   open ScarlettMidiControl.xcodeproj
   ```
2. In Xcode, select the "ScarlettMidiControl" scheme and build/run. The app appears as a menu bar icon.
3. Popover flow:
   - Connection: Discover → Connect → approve the client in Focusrite Control when prompted.
   - MIDI source: Pick exactly one MIDI input port (by name; bound by UID under the hood).
   - Learn: Click Learn next to a control, move a knob (CC preferred) on the selected port; mapping saves automatically (UID + channel + type + number).
   - Clear: Use Clear to unmap a control.

Notes:
- If hardware isn't detected, quitting and relaunching the Focusrite Control app (which restarts its server) often helps.
- Local network permissions are not required on macOS, but firewall prompts may appear on first UDP/TCP use.

---

## What’s implemented vs TODO

Implemented:
- SwiftUI menu bar UI: connection status, MIDI picker, primary controls, per-control Learn/Clear
- CoreMIDI input from a single selected port (UID-based); MIDI Learn callback
- Persistence for selected MIDI port UID and mappings (JSON in Application Support)
- Protocol framing helpers (encode/decode `Length=<hex>` frames)

TODO (verify against live server):
- Replace discovery stub with real UDP broadcast and XML response parsing
- Implement TCP handshake (client-details), approval state transitions, and subscribe to device updates
- Map device XML paths to `Scarlett18i20Gen2Model` fields (monitor L/R, mute, mixes)
- Send control updates (e.g., set monitor volumes/mute) using the verified message format

All unverified assumptions are marked clearly in code comments.

---

## Repository hygiene

- License: MIT (`LICENSE`)
- Xcode ignores in `.gitignore`
- Sources organized into `App/` and `Sources/` with three frameworks
- Project defined in `project.yml` for reproducible Xcode project generation

---

## Contributing

Please avoid copying proprietary Focusrite code or pasting verbatim copyrighted source from third-party apps. Implementation should be based only on public reverse‑engineering notes and what you can observe from your own device/server.

---

## Acknowledgements

Thanks to community reverse‑engineering efforts that documented parts of the classic protocol (linked above).

# New project

This project was created by a Cursor cloud agent.

---

## CI

Tests and SwiftLint run on Buildkite (org `catkins-test`, hosted macOS queue `hosted-macos`).

- Pipeline definition: `.buildkite/pipeline.yml` (lint + `swift test`)
- Local: `./scripts/ci.sh` — runs `swift test`, and SwiftLint when it is installed (`brew install swiftlint`)
- SwiftLint config: `.swiftlint.yml` (relaxed Swift 6 / SwiftUI rules)

The Buildkite pipeline clones `https://origin.cursor.com/catkins/scarlett-midi-remote.git`. There is no GitHub remote, so GitHub webhooks are not configured; start builds from the Buildkite UI until a GitHub repo is connected.
