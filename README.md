# Distortionz Trucking

> Premium freight trucking job for Qbox/FiveM — depot dispatcher, real trailer hookup, weighted cargo, distance-tiered payouts, cargo manifest for pull-overs.

![FiveM](https://img.shields.io/badge/FiveM-cerulean-yellow?style=flat-square&labelColor=181b20)
![Qbox](https://img.shields.io/badge/Qbox-required-red?style=flat-square&labelColor=dfb317)
![License](https://img.shields.io/badge/License-MIT-brightgreen?style=flat-square)
![Version](https://img.shields.io/github/v/release/Distortionzz/Distortionz_Trucking?style=flat-square&color=d4aa62&label=version)

A polished, feature-rich script where players take freight contracts from a depot dispatcher, hook up a real trailer with a real truck, deliver weighted cargo across the map, and earn clean money — complete with cargo manifest paperwork for police pull-overs.

---

## ✨ Features

### 🎯 Depot Job System
- 🤝 Underground dispatcher ped with `ox_target` interaction
- 🗺️ Configurable depot location with map blip
- 🔒 Cooldown tracking per player between deliveries
- 🚫 Anti-spam protection (one active run per player)
- ⏱️ 15-minute time limit (configurable)

### 🚛 Realistic Trailer Hookup
- 🎯 Truck spawns at one location, trailer at another
- 🔄 Player must back the truck into the trailer to attach
- 🚫 No magic snap-on — the 5th wheel must physically connect
- 🔓 Truck spawns unlocked with auto-key grant via `vehiclekeys:client:SetOwner`
- 🛡️ Auto-defeats `qbx_smallresources` lock attempts during the run
- 🧹 Both truck + trailer despawn cleanly on delivery

### 📦 Tiered Weighted Cargo
- 🎲 Random cargo type rolled on each pickup based on rarity:

| Tier | Cargo | Chance | Base Pay | Damage Penalty |
|------|-------|--------|----------|----------------|
| 🥫 Common | Food Supplies | 50% | $350 | 0.7× |
| 📦 Standard | Electronics | 30% | $600 | 0.5× |
| ☣️ Risky | Hazardous Materials | 15% | $950 | 0.4× |
| 🔒 Premium | Classified Freight | 5% | $1,500 | 0.3× |

### 🗺️ 8 Random Drop-off Locations
- Paleto Bay Warehouse
- Sandy Shores Storage
- LSIA Freight Hub
- Paleto Distribution
- Grapeseed Depot
- Mount Chiliad Outpost
- Vespucci Cargo
- Cypress Flats Yard

### 💎 Glassy NUI Panel
- 🟡 Pulsing yellow dot status indicator
- ⏱️ Live countdown timer with **amber → red blinking** warning states
- 🏷️ Animated stage pill — `PICKUP` → `IN TRANSIT` → `DELIVERED`
- 📦 Cargo + drop-off shown live
- 🟡 Full manifest section with ID, container, weight, shipper, consignee
- 💰 Live payout display

### 📋 Cargo Manifest Paperwork (RP Touch)
Players receive an `ox_inventory` item containing the freight manifest as proper paperwork. When a cop pulls them over, they hand over the manifest and the cop hovers it to read all the details.

Each manifest randomly generates:
- 🆔 **Manifest ID** (`DZ-FRT-XXXXXX`)
- 📋 **ISO 6346 container number** (4 letters + 7 digits)
- ⚖️ **Realistic gross weight** per cargo class
- 🏢 **Random shipper** (Maze Bank Logistics, Vinewood Imports, Sprunk, Whiz Wireless, etc.)
- 🏪 **Random consignee** (Burger Shot, Pisswasser, eCola, Schlongberg Sachs, etc.)
- 📍 **Destination warehouse**
- 🕒 **Issue timestamp**
- 🏷️ **Carrier**: San Andreas Freight Co.

All metadata fields render as labeled tooltip rows when the cop hovers the item.

### 👮 Police Integration
- 🚨 Configurable inspection alert chances per cargo tier:
  - Food: 0%
  - Electronics: 0%
  - Hazmat: 12%
  - Classified: 25%
- 📡 Real-time blips on cop maps with flashing effect
- 🚓 Supports `police`, `sheriff`, `sasp` jobs (configurable)

### 💸 Damage-Based Pay Penalty
- ⚠️ Trailer health below 700 HP triggers a multiplier penalty
- 🎯 Penalty severity scales with cargo type (hazmat/classified hit harder)
- 🚫 Trailer destruction = run cancelled

### 🛡️ Anti-Exploit Protection
- ✅ Server validates dropoff distance (≤25m)
- ✅ Cooldown enforced server-side (30s between runs)
- ✅ Single active job per player
- ✅ Player abandons trailer (>150m on foot) = run cancelled
- ✅ Time limit enforced
- ✅ Manifest auto-cleans on delivery, cancel, and disconnect

### 🧾 Standardized Version Checker
- 📡 GitHub `version.json` polling on resource start
- 🔍 HTML-response detection (catches misconfigured URLs)
- 🆔 Custom User-Agent (avoids GitHub rate limits)
- 🟢 Color-coded console output

---

## 📦 Resource Name

```
distortionz_trucking
```

## 🛠 Installation

1. 📥 Drop the folder into your `resources/` folder
2. ⚙️ Open `config.lua` and configure:
   - `Config.Depot.coords` — where the dispatcher spawns
   - `Config.Spawn.truck` / `trailer` — vehicle spawn points
   - `Config.Dropoffs` — delivery locations
   - `Config.Cargo` — tiers, weights, and payouts
   - `Config.Police` — alert percentages per cargo type
3. 📝 Add to your `server.cfg`:
   ```cfg
   ensure distortionz_trucking
   ```
4. 🧾 **Required:** add the manifest item to `ox_inventory/data/items.lua`:
   ```lua
   ['cargo_manifest'] = {
       label       = 'Cargo Manifest',
       weight      = 50,
       stack       = false,
       close       = true,
       description = 'Official freight manifest paperwork.',
   },
   ```
5. 🖼️ (Optional) Drop `cargo_manifest.png` into `ox_inventory/web/images/` for a custom icon
6. 🔄 Restart your server

## 🧩 Dependencies

- 🟦 [`qbx_core`](https://github.com/Qbox-project/qbx_core)
- 🛠️ [`ox_lib`](https://github.com/overextended/ox_lib)
- 🎯 [`ox_target`](https://github.com/overextended/ox_target)
- 🎒 [`ox_inventory`](https://github.com/overextended/ox_inventory)
- 🔔 [`distortionz_notify`](https://github.com/Distortionzz/Distortionz_Notify) *(optional — falls back to ox_lib)*

## ⚙️ Configuration Highlights

| Setting | Default | What it does |
|---------|---------|--------------|
| `Config.Job.timeLimitSeconds` | `900` | 15 minutes per run |
| `Config.Job.minDropoffSpeed` | `8.0` | Max mph at dropoff to trigger |
| `Config.Job.trailerDamageThreshold` | `700.0` | Below this HP = damage penalty |
| `Config.Job.abandonDistance` | `150.0` | Foot distance from trailer = abandon |
| `Config.Job.cooldownAfterDeliverySec` | `30` | Cooldown between runs |
| `Config.SearchZone.radius` | n/a | Hookup is location-based |
| `Config.Manifest.enabled` | `true` | Toggle the paperwork item |
| `Config.Police.alertChance.hazmat` | `12` | % chance of inspection alert |
| `Config.VersionCheck.enabled` | `true` | Hits GitHub on resource start |

## 🎮 Player Flow

1. 🚶 Walk up to the depot dispatcher
2. 🤝 Use `ox_target` → "Talk to Dispatcher"
3. 📦 Server rolls a weighted cargo type
4. 🚛 Truck spawns at one spot, trailer at another
5. 🔄 Drive truck, back into trailer, hook up the 5th wheel
6. 🗺️ GPS routes you to a random dropoff
7. 📋 Manifest paperwork lands in your inventory
8. 🚓 If police are nearby and cargo is hot, expect an inspection
9. 🐢 Slow to ≤8mph at the dropoff, press **E** to deliver
10. 💰 Tiered reward to bank — minus damage penalty if trailer is beat up

## 🎭 RP Pull-over Scenario

```
COP:    Sir, can I see your manifest please?
PLAYER: *opens inventory, gives Cargo Manifest*
COP:    *hovers, reads tooltip*
        Manifest:    DZ-FRT-K9X4P2
        Container:   MSCU1234567
        Cargo:       Hazardous Materials
        Gross weight: 7,243 kg
        Shipper:     Bilkinton Research
        Consignee:   Schlongberg Sachs
        Destination: Paleto Bay Warehouse
        Issued:      2026-05-02 18:33
        Carrier:     San Andreas Freight Co.

COP:    Everything checks out. Drive safe.
```

## 📝 Changelog

### v1.0.9
- 💎 Expanded NUI panel with full manifest details section
- 🆔 Live HUD now shows manifest ID, container, weight, shipper, consignee

### v1.0.8
- 🏷️ Registered metadata fields with `ox_inventory:displayMetadata` so all rows show in tooltip
- 🔓 Continuous unlock loop for full job lifecycle (defeats post-exit auto-locking)

### v1.0.7
- 🔧 Fixed manifest metadata not generating (renamed reserved `weight` key)

### v1.0.6
- 📋 Upgraded manifest with ISO container numbers, random shippers/consignees
- ⚖️ Realistic weight ranges per cargo class

### v1.0.5
- 🚛 Truck despawns alongside trailer on delivery (auto-ejects driver)
- 📋 Cargo manifest paperwork item with metadata

### v1.0.4
- 🔧 Fixed false-positive trailer attachment (deterministic check + grace period)
- 🔑 Auto-grant keys via `vehiclekeys:client:SetOwner` event

### v1.0.3
- 📐 Migrated all coordinates to `vec2/3/4` format

### v1.0.2
- 🔓 Truck unlock loop to defeat auto-lock scripts
- 🔗 Triple-method trailer attachment detection

### v1.0.1
- 📍 Updated default truck/trailer spawn to road-side locations
- 🗑️ Removed `qbx_vehiclekeys` hard dependency

### v1.0.0
- 🎉 Initial release

---

## 📜 License

MIT — see `LICENSE`.

---

**Built with 🟡 by Distortionz** · Part of the [Distortionz RP](https://github.com/Distortionzz) script lineup
