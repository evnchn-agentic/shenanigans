# bambu-studio-shenanigans — non-obvious Bambu Studio (slicer/host) gotchas

> A grab-bag of empirically-hit **Bambu Studio** app-behaviour traps — each cost real time. Less
> "catastrophic footgun", more "the UI silently did something other than what you asked".

## LAN-Only mode drops a printer entirely after ONE failed connect

A manually-added printer **vanishes from "My Device" completely** the first time it fails to connect
— it doesn't grey out or show offline, it's just *gone*. Re-add from scratch: Device tab → printer
dropdown (top-left) → **"Bind with Access Code"** → needs **IP + Access Code**, then **SN + Printer
model**.
- The model dropdown **DEFAULTS WRONG** (it can guess an A1 for a P1S) — pick the right one or it
  binds as the wrong machine.
- LAN discovery (SSDP/mDNS) does **not** traverse a routed/tunnelled link, so a remote printer never
  auto-appears — manual "Bind with Access Code" is the only path over such a link.
- **Storage is NOT browsable in LAN-Only mode** ("Browsing file in storage is not supported…") — you
  can't verify an uploaded file from the app; trust the "sent to storage" toast.

## Plate-type has TWO controls that silently desync

A **global bed-type card** (top printer panel) AND a **per-plate "Plate type"** (Plate Settings,
bottom-left) look like one setting but can differ.
- **The per-plate one drives slicing.** Proof trick: if the slice is stale vs the active plate,
  "Slice plate" goes GREEN (dirty); if it stays GREY after you (re)confirm a plate type, the existing
  slice already matches that plate. Use this dirty/grey test to *prove* what the slice actually used.
- Re-selecting the *same* value does NOT dirty the slice (no-op). To force a genuine re-slice, pick a
  *different* value then switch back.

## Loading a profile / switching printer resets things

- Loading a MakerWorld print profile **resets the project printer** to that profile's default.
- Switching the project printer profile **resets the plate type** to the new printer's default and can
  push objects into an **"Outside" group**; after deleting the offending objects the empty "Outside"
  group often remains (harmless).
- A printer-profile switch pops a **"save unsaved changes?"** dialog — if the only "change" is the
  transient switch and you've saved the real project, click **No** so you don't bake it into the .3mf.

## Send (storage only) vs Print plate (starts the print)

The chevron next to the green button offers Print plate / Print all / **Send** / Send all / Export.
**"Send"** uploads the .gcode.3mf to the printer's storage **without starting a print**; "Print plate"
sends AND starts. For send-to-storage-no-print, use **Send**.

## Prime tower ≠ purge tower — disable it to reclaim a packed plate

On AMS multi-color, the **bulk** filament-change purge is ejected out the **back chute as "poops"** —
it does NOT pile into the prime/wipe tower. The prime tower is only a **nozzle-tip wipe** for color
purity at the start of each new-color region. So when a packed plate throws *"Conflicts of gcode paths
(WipeTower <-> obj)"* / *"Prime Tower is too close to others"*, you can just **DISABLE it**: Process →
Others → Prime tower → uncheck Enable. Purge still goes to the chute; the only cost is a hair of color
bleed at the start of each new-color region. **Do NOT** reflexively enable *"Purge into objects'
infill"* to silence the collision — that's a *different* feature (buries wrong-color filament inside
the part).

## Verify dimensions before deleting multi-part objects

Object **NAMES don't reliably encode size**; the **X-width + volume in the selection panel do**. On a
body+lid set, the tall objects are bodies and the flat ones are lids — click each, read the size,
then delete, or you can delete the wrong half.

## Bed exclusion needs a generous edge margin

On a 256×256 plate the printable/exclusion zone rejects objects near the edge: both a 250 mm (≈3 mm
margin) and a 240 mm (≈8 mm margin) object threw *"too close to exclusion area"*. Safe margin is
**~17 mm+**. Consequence for tiling: a clean grid of Ø40 discs caps at **5×5 = 25** at ~20 mm margins.

## Pinning the exact MakerWorld profileId (the cards don't show it)

A MakerWorld model has multiple print profiles with non-obvious names, and the cards don't show the
numeric profileId. The page HTML is Cloudflare/JS-blocked for `curl`, but the JSON API works with a
browser UA:
```bash
curl -A 'Mozilla/5.0' https://makerworld.com/api/v1/design-service/design/<designId>
```
→ `instances[]`, each with `id` (the profileId in the URL `#profileId-<id>`) and `title`. Map your
target id → title, then pick that exact card in the embedded browser.
