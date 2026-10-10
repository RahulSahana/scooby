# Scooby — Professional EV Dashboard for JK BMS

**Scooby** is a high-performance Flutter application designed to interface directly with electric vehicle drivetrains via Bluetooth Low Energy (BLE). It provides a premium, real-time dashboard for vehicles equipped with **JK Battery Management Systems (BMS)**, combining deep telemetry insights with hardware-level security controls.

> **Note on structure:** This document is an excerpted set of sections from a larger internal reference (hence the non-sequential Part numbers — e.g. Part 5 is followed by Part 8). Numbering has been left as-is to match the source; missing parts were not included in this excerpt.

---

# PART 1 — PROJECT OVERVIEW

## 2-Minute Interview Answer

> "Scooby is a specialized Flutter application designed to interface directly with electric vehicle drivetrains via Bluetooth Low Energy (BLE). It specifically targets vehicles using JK Battery Management Systems (BMS).
>
> The project solves the critical problem of 'telemetry transparency' — most budget or DIY EV conversions lack a sophisticated dashboard. Scooby provides real-time monitoring of voltage, current, and cell-level health, while also acting as a security tool with a remote 'Motor Kill Switch' and Charge Cutoff.
>
> Technologically, I built a custom binary protocol parser to handle the JK BMS frame structure (`0x55 0xAA 0xEB 0x90` header). I used Provider for state management and FlutterBluePlus for the BLE stack. One of the highlights is a robust Stateful Auto-Reconnection Loop and a Software Safety Interlock that prevents hazardous hardware commands from executing while the vehicle is in motion. It's an example of how high-level cross-platform UI can securely manage low-level hardware."

---

## 5-Minute Detailed Answer

The project serves EV enthusiasts and micro-mobility owners who need a reliable dashboard.

### Main Features

1. **Live Telemetry:** Real-time stream of pack voltage, current (A), and power (W).
2. **Cell Diagnostics:** Visualizing individual cell voltages (up to 24–32S) to detect imbalances before they lead to battery failure.
3. **Hardware Overrides:** Toggleable MOSFETs for charging and discharging.
4. **Intelligent Safety:** The 'Interlock' system monitors discharge current; if the motor is pulling power, the UI physically locks the 'Motor Power' and 'Charge' switches to prevent MOSFET arcing or sudden propulsion loss.
5. **Garage Management:** Remembers the MAC addresses of multiple scooters for instant auto-connecting on launch.

### Major Technical Components

- **Protocol Layer:** A manual binary parser using `ByteData` to decode little-endian integers and ASCII strings from raw BLE notify chunks.
- **Command Pipeline:** A serialized write pipeline that handles the mandatory 10-digit authentication handshake (`802626052E`) before executing register writes.
- **UI System:** A unified design system using Theme Extensions for Light/Dark mode and `FittedBox` text scaling to handle high-accessibility font settings without layout breakage.

### Why This Tech?

- **Flutter:** Chosen for its ability to create high-performance custom animations (like the sine-wave battery fill) and consistent BLE performance on both Android and iOS.
- **Provider:** For its simplicity in small-to-medium hardware-driven apps, allowing a clean bridge between the `BleService` and the UI.
- **Shared Preferences:** Used for persistent storage of 'Garage' metadata and user preferences.

### Architecture

The app follows a Service-Based MVVM architecture. The `BatteryProvider` acts as the single source of truth (the ViewModel), delegating hardware complexity to the `BleService` and protocol complexity to the `JkBmsParser`.

---

# PART 2 — COMPLETE PROJECT STRUCTURE

```
Scooby/
├── lib/
│   ├── core/
│   │   └── utils/
│   │       └── jk_code_generator.dart    # Logic for generating time-based BMS codes
│   ├── models/
│   │   └── battery_data.dart             # Immutable Data Model for telemetry
│   ├── parsers/
│   │   └── jk_bms_parser.dart            # The "Brain": Binary protocol decoding
│   ├── providers/
│   │   ├── battery_provider.dart         # Central State & Logic bridge
│   │   └── theme_provider.dart           # Theme state persistence
│   ├── screens/
│   │   ├── charge/                       # Wavy animation & ETA logic
│   │   ├── connect/                      # Radar scanning & Auto-connect loop
│   │   ├── home/                         # Motion GIF & Vital Stats
│   │   └── profile/                      # Security, Garage & About BMS
│   ├── services/
│   │   ├── ble_service.dart              # Bluetooth lifecycle & frame routing
│   │   └── jk_command_service.dart       # Frame builder & Secure Write pipeline
│   ├── theme/
│   │   └── app_colors.dart               # Theme Extensions (Semantic Tokens)
│   ├── widgets/
│   │   ├── battery_arc.dart              # Custom Gauge widget
│   │   └── connection_badge.dart         # Stateful Interactive status button
│   └── main.dart                         # App Entry, Theme & PageView Nav
├── pubspec.yaml                          # Dependency management (FBP, Provider, etc.)
└── android/                              # Android specific Manifest/Permissions
```

### Architecture Analysis

- **Pattern:** MVVM (Model-View-ViewModel).
- **Cleanliness:** The separation between the Parser (Domain), Service (Data), and Provider (ViewModel) is strong.
- **Architectural Problem:** The `BleService` holds a reference to `BatteryProvider` (Constructor Injection). While functional, in a larger system, this should be inverted using a Repository Pattern or Streams/Event Bus to prevent a circular dependency feel.

---

# PART 3 — SYSTEM DESIGN

## High-Level ASCII Diagram

```
┌──────────────┐         ┌──────────────┐
│   UI LAYER   │◄────────┤  THEME EXT   │
│  (Screens)   │         └──────────────┘
└──────┬───────┘
       ▼
┌──────────────┐         ┌──────────────┐
│  VIEW MODEL  │◄────────┤ LOCAL STORAGE│
│  (Provider)  │         │ (SharedPrefs)│
└──────┬───────┘         └──────────────┘
       ▲ (Listen/Notify)
       ▼
┌──────────────┐         ┌──────────────┐
│ BLE SERVICE  │◄───────►│  BMS PARSER  │
│ (Stack/Link) │         │  (Protocol)  │
└──────┬───────┘         └──────────────┘
       ▼
┌──────────────┐         ┌──────────────┐
│  BLE STACK   │◄───────►│ PHYSICAL BMS │
│(FBP Library) │         │  (Hardware)  │
└──────────────┘         └──────────────┘
```

- **Data Flow:** Unidirectional telemetry updates (BMS → Parser → Provider → UI).
- **Control Flow:** Command propagation (UI → Provider → Service → BMS).
- **Lifecycle:** `BleService` lives for the app's entire duration; `ConnectScreen` manages the scanning lifecycle.
- **State:** Centralized in `BatteryProvider`. Business logic (Interlocks) lives here and in `BleService`.

---

# PART 4 — END-TO-END FEATURE FLOWS

## Feature: Toggling Motor Power (Discharge Kill Switch)

1. **User Action:** User taps the 'Motor Power' switch on the Home/Profile screen.
2. **UI:** Calls `batteryProvider.toggleDischarging(newValue)`.
3. **ViewModel (Provider):**
    - Performs Optimistic Update (UI reflects change instantly).
    - Checks the Interlock: If current ≤ -0.6A, it aborts and notifies the user.
    - If safe, calls `bleService.toggleDischargeMosfet()`.
4. **Service (BLE):**
    - Sets `isHardwareCommandPending = true` (pauses the telemetry radar).
    - Calls `_commandService.sendAuthorization()` (BMS Password).
    - Waits 500ms (BMS processing window).
    - Calls `_commandService.setDischargeMosfet()`.
5. **Command Service:** Builds a perfect 20-byte packet (Header + `0x02` + Reg `0x1E` + 12-byte padded value + CRC).
6. **Hardware:** BMS authenticates, clicks the relay, and acknowledges.
7. **Service (BLE):** Resumes telemetry polling; `isHardwareCommandPending = false`.
8. **UI Update:** Next telemetry frame (Type `0x02`) confirms the hardware state, and the Switch reflects truth.

---

# PART 5 — COMPONENT RESPONSIBILITIES

| Class | Responsibility | Depends On | Used By | Methods |
| :--- | :--- | :--- | :--- | :--- |
| `BatteryProvider` | State holder & UI Bridge | `BleService` | UI Screens | `updateTelemetry`, `toggleCharging` |
| `BleService` | BLE lifecycle & Traffic Cop | `JkCommandService`, `JkBmsParser` | `BatteryProvider` | `connect`, `_startAutoReconnectLoop` |
| `JkBmsParser` | Protocol Decoder | `BatteryData` | `BleService` | `parseBatteryData`, `parseDeviceInfo` |
| `JkCommandService` | Protocol Encoder | None | `BleService` | `buildWriteCommand`, `calculateCrc` |
| `BatteryData` | Immutable Data Model | None | Provider/Parser | `copyWith`, `empty` |

---

# PART 8 — BLUETOOTH / HARDWARE COMMUNICATION

This is the core of the project.

- **Service Discovery:** Targets Service `0xFFE0` and Characteristic `0xFFE1`.
- **Buffering:** Uses a `packetBuffer` (`List<int>`) to accumulate BLE notify chunks.
- **Frame Detection:** Implements a sliding window search for the header `0x55 0xAA 0xEB 0x90`.
- **Endianness:** Strictly Little Endian for telemetry (voltage/current) and Big Endian for certain system time registers.
- **Reconnection:** Uses a Stateful Auto-Reconnect Loop. If a `BluetoothConnectionState.disconnected` event triggers, it launches a 5-second periodic timer that attempts to re-establish the link until successful or manually overridden.

### BMS Protocol Reference

- Service UUID: `0xFFE0`
- Characteristic UUID: `0xFFE1`
- Header: `0x55 0xAA 0xEB 0x90`
- Command Structure: 20-byte frames (Header + Payload + CRC)
- Frame Identification: `0x01` (Settings), `0x02` (Cell Info), `0x03` (Device Info)

> **Fixed inconsistency:** the original doc gave two different byte orders for the frame header (`0x55 0xAA 0xEB 0x90` in Part 8 vs. `AA 55 90 EB` in the legacy reference section). These have been reconciled to a single value here. Please confirm against your actual firmware/capture logs which order is correct before relying on this for parsing.

---

# PART 10 — DESIGN PATTERNS

1. **Observer Pattern:** Used by `ChangeNotifier` (Provider) to update the UI when hardware stats change.
2. **Factory Pattern:** `BatteryData.empty()` and `BatteryData.demo()` for clean state initialization.
3. **Strategy Pattern (Planned):** The `ConnectionMode` enum (BLE vs HTTP) allows the app to swap data sources based on vehicle capability.
4. **Adapter/Wrapper:** `AppColors` extension acts as an adapter for the system `ThemeData`.

---

# PART 13 — SECURITY REVIEW

- **Vulnerability:** The BMS password (`802626052E`) is currently stored as a string in the provider.
- **Recommendation:** Move sensitive hardware passwords into Flutter Secure Storage (Keychain/Keystore) rather than `shared_preferences`.
- **Software Safety:** The Interlock System is a critical security layer that prevents "switching under load," which can weld MOSFETs shut.

---

# PART 18 — TECHNICAL DEBT

1. 🟡 **Offset Hardcoding (Medium):** Protocol parsing relies on magic numbers (e.g., `frame[11]`). Fix: use a Register Map class.
2. 🟠 **Error Handling (High):** BLE write calls lack comprehensive retry-logic if the characteristic is busy.
3. 🔴 **Testing (Critical):** Zero unit tests for the `JkBmsParser`. A single byte offset error could show 0V when the battery is full.

---

# PART 23 — FINAL CHEAT SHEET

### Top 5 Technical Challenges Solved

1. **Partial Frame Stitching:** Handling BLE chunks that arrive out of order or split across packets.
2. **Multi-Stage Auth Write:** Sequencing Password → Delay → Command → Poll.
3. **Accessibility Layout:** Using `FittedBox` to prevent UI breakage on senior-friendly font sizes.
4. **Persistent Garage:** Multi-vehicle memory logic.
5. **State Synchronization:** Ensuring the UI Switch matches the hardware state even after a disconnect.

### Top 3 "Killer" Interview Questions

1. *"How did you handle the risk of cutting motor power while driving?"*
   **Answer:** The 0.6A Software Interlock.
2. *"Why do you pad your BLE packets to exactly 20 bytes?"*
   **Answer:** Rigid JK BMS firmware requirements.
3. *"How does your app handle background reconnection?"*
   **Answer:** The Stateful Timer loop in `BleService`.

---

Developed with ❤️ by **Rahul Sahana**