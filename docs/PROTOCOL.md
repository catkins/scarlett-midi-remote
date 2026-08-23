# Classic Focusrite Control protocol (notes)

Verified against a live `FocusriteControlServer` on macOS talking to a Scarlett 18i20 (2nd Gen). Still treat device-specific parameter IDs as discovered at runtime, not hardcoded.

References (do not vendor their code):
- `https://github.com/raduvarga/Focusrite-Midi-Control` (public reverse-engineering notes)
- `https://gist.github.com/daveyijzermans/f0354858b3eb765e19361ab85a6bc55b` (UDP discovery)
- `https://github.com/Mathieu2301/Focusrite-Control-API` (Node API over classic server)

## Discovery (UDP) — verified

Client sends a framed payload to ports 30096, 30097, 30098 (localhost unicast is enough when the server is on the same Mac):

```
Length=<6hex> <client-discovery app="SAFFIRE-CONTROL" version="4" device="iOS"/>
```

Live reply:

```
Length=000068 <server-announcement app='SAFFIRE-CONTROL' version='4' hostname='…' port='49152'/>
```

Use the UDP source address as the TCP host (the hostname attribute can be a `.localdomain` name). Prefer discovery over pinning a port.

## Framing — verified

The server concatenates header-only frames:

```
Length=00002b <client-details id="…" />Length=007447 <device-arrival>…</device-arrival>
```

- `Length=` + 6 hex digits + space + UTF-8 XML payload
- Length is payload bytes only
- Footer is optional; we send header-only to match the server

## TCP handshake — verified

1. Connect to the announced TCP port.
2. Send:
   ```xml
   <client-details hostname="Scarlett MIDI Control" client-key="{stable-uuid}"/>
   ```
   Persist `client-key` so Focusrite Control can remember approval.
3. Keep-alive every ~3s: `<keep-alive/>`
4. Server replies with `<client-details id="…"/>`, then `<device-arrival>` for each device, then a `<set devid="…">` snapshot of current values.
5. Subscribe:
   ```xml
   <device-subscribe devid="1" subscribe="true"/>
   ```
6. Approve the client in Focusrite Control → Settings → Remote Devices. Writes are ignored until authorised. Expect:
   ```xml
   <approval id="…" authorised="true"/>
   ```

## Device model (Scarlett 18i20 Gen 2) — verified live

Do not hardcode IDs. Parse them from `<device-arrival>`:

- Analogue `name="Monitor Output 1|2"` → `gain` / `mute` child ids (software per-channel)
- `monitoring/hardware-controls` → stereo hardware `gain`, `dim`, `mute`, plus `min-gain` / `max-gain` (live: −128…0 dB)

Set values:

```xml
<set devid="1"><item id="1127" value="-27"/><item id="1129" value="true"/></set>
```

Inbound snapshots use the same `<set>` / `<item>` shape.


## Mixer (per-output mix) — verified live

Each hardware output’s `source` value is a mix id (Mix A–E, L/R pair). Mixer input slots have `source` (hardware/playback element id) and `stereo`. When `stereo` is true, two consecutive slots are one strip — one fader writes both (and the paired R mix).

Empty slots are omitted from the snapshot (treat missing mute/solo/source as false/empty).

## Meters — verified live

Inputs, playback, outputs, and each mix bus have a `<meter id="…"/>`. Values are dBFS in `<set>` items (`-128` is silence). Subscribe streams them. Per-strip VU uses the assigned source meter (max of L/R when stereo-linked); the output row uses the selected output meter.

Writes:


```xml
<set devid="1"><item id="55" value="0"/><item id="57" value="true"/></set>
```
