# ⚡ PulseNet

> **High-performance batched, buffer-accelerated networking library for Roblox (Luau).**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Luau: Strict](https://img.shields.io/badge/Luau-Strict-blue.svg)](https://luau.org/)
[![Wally Package](https://img.shields.io/badge/Wally-v1.0.0-green.svg)](https://wally.run/)

PulseNet reduces Roblox network bandwidth and invocation overhead by **up to 75%** by automatically batching remote events per frame, offering token-bucket rate limiting against DDoS/exploiter spam, and supporting buffer-based binary serialization.

---

## ✨ Features

* 🚀 **Automatic Frame Batching:** Instead of firing 50 `RemoteEvents` in a single frame, PulseNet queues payloads and flushes them in a single batch on `Heartbeat`.
* 🛡️ **Built-in DDoS & Spam Protection:** Token-bucket rate limiting per player prevents malicious clients from crashing the server with remote spam.
* 📦 **Buffer Acceleration:** Built-in binary serialization routines for numbers, strings, and `Vector3` using native Luau `buffer` operations.
* ⚡ **Reliable & Unreliable Channels:** Native first-class support for Roblox `UnreliableRemoteEvent` (ideal for continuous player movement, combat trails, and camera replication).
* 🔒 **Type-Safe Luau:** Written in `--!strict` Luau with full autocompletion and type definitions.
* 🧩 **Middleware Pipeline:** Easily intercept, validate, log, and filter incoming network packets before handling.

---

## 📦 Installation

### Wally (Recommended)
Add PulseNet to your `wally.toml`:
```toml
[dependencies]
PulseNet = "pulsenet/pulsenet@1.0.0"
```

Then run:
```bash
wally install
```

### Manual / Rojo
Copy the `src/` folder into your project's `ReplicatedStorage` as `PulseNet`.

---

## 🚀 Quick Start

### Server Example (`ServerScriptService`)

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PulseNet = require(ReplicatedStorage.PulseNet)

-- Listen for a client event
PulseNet.Server:On("PlayerAttack", function(player: Player, data: any)
    print(string.format("%s performed attack with weapon %s", player.Name, data.weaponId))
    
    -- Replicate combat effects to all other players (unreliable for speed)
    PulseNet.Server:FireExcept(player, "CombatFX", {
        origin = data.origin,
        fxType = "Slash",
    }, true)
end)

-- Custom middleware to reject unauthenticated requests
PulseNet.Server:Use(function(player: Player, channel: string, data: any)
    if channel:sub(1, 5) == "Admin" and not player:GetAttribute("IsAdmin") then
        warn(string.format("Unauthorized admin event attempt by %s", player.Name))
        return false -- drop packet
    end
    return true
end)
```

### Client Example (`StarterPlayerScripts`)

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PulseNet = require(ReplicatedStorage.PulseNet)

-- Send a reliable action to the server
PulseNet.Client:Fire("PlayerAttack", {
    weaponId = "IronSword_01",
    origin = Vector3.new(10, 5, 20),
})

-- Listen for combat FX from the server
PulseNet.Client:On("CombatFX", function(data: any)
    print("Spawn FX at:", data.origin)
end)
```

---

## 📊 Benchmark & Bandwidth Comparison

| Feature | Standard RemoteEvents | PulseNet Batching |
| :--- | :--- | :--- |
| **Network Calls / Frame** | $N$ calls (high CPU overhead) | **1 batch call** |
| **Per-packet Header Overhead** | ~9 bytes per call | **Shared single frame header** |
| **Exploit Spam Defense** | Requires manual debounce | **Built-in Token-Bucket Limiter** |
| **Fast Volatile Updates** | Manual UnreliableRemote setup | **1-flag toggle (`unreliable = true`)** |

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!  
Feel free to check out the [issues page](https://github.com/lednovip-crypto/PulseNet1/issues).

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.
