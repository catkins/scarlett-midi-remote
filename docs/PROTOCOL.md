# Classic Focusrite Control protocol (notes)

This document tracks public, reverse‑engineered behavior that should be VERIFIED against a live `FocusriteControlServer`. Do not treat this as authoritative; contribute updates as you test.

References (do not vendor their code):
- `https://github.com/raduvarga/Focusrite-Midi-Control` (Swift macOS, Gen 2 era)
- `https://gist.github.com/daveyijzermans/f0354858b3eb765e19361ab85a6bc55b` (UDP discovery)
- `https://github.com/Mathieu2301/Focusrite-Control-API` (Node API over classic server)

## Discovery (UDP)

Client broadcasts to ports 30096, 30097, 30098 (same payload to each):

```
Length=<6hex> <client-discovery app="SAFFIRE-CONTROL" version="4" device="iOS"/>
```

Server replies with XML that includes a listening TCP port (often near 49152). Prefer discovery to hardcoding the port, as it can vary.

Open questions:
- Exact casing and attributes of the `client-discovery` element
- Whether replies are unicast to the sender or broadcast
- Encoding: UTF‑8 assumed

## Framing

Messages are wrapped with ASCII headers (and often footers):

```
Length=0001AF <xml ...> Length=0001AF
```

- The 6‑digit hex after `Length=` is the payload length in bytes (XML only, not counting the headers).
- Some implementations accept the message if only the header is present.

Our `ProtocolFraming` accepts both header+footer and header‑only during bring‑up, and always emits header+footer on send. Tighten if needed once behavior is verified.

## TCP handshake

After connecting to the discovered TCP port:
1. Send client details (name + key). Example (UNVERIFIED):
   ```xml
   <client-details name="Scarlett MIDI Control" key="swiftui"/>
   ```
2. Periodic keep‑alive every ~3s:
   ```xml
   <keep-alive/>
   ```
3. Expect a device description and an approval state; the user approves the client in Focusrite Control UI, then the connection transitions to "connected" and value updates flow.

Open questions:
- Exact XML tags/attributes for approval, subscription, and device parameters
- Subscription/resubscription semantics
- Snapshot request format

## Device model (Scarlett 18i20 Gen 2)

Initial target parameters:
- Monitor Left / Right volume (dB)
- Monitor mute (boolean)
- Mix outputs (nice‑to‑have after MVP)

As you verify XML parameter paths, map them into `Scarlett18i20Gen2Model` and implement:
- `requestDeviceSnapshot()` to populate the model
- setters (e.g., `setMonitorMute(_)`) that encode the correct control message

## Tips

- If device isn't detected, quitting and relaunching Focusrite Control often restarts the server and fixes discovery.
- Keep discovery defaulting to UDP; avoid pinning a single TCP port.
- Keep only a single selected MIDI input open; do not listen to all ports at once.

