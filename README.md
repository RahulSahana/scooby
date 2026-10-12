# Scooby

Scooby is a Flutter companion app for electric vehicles equipped with a compatible JK Battery Management System (BMS). It connects over Bluetooth Low Energy (BLE) to present battery information, charging status, vehicle range estimates, and route progress in one place.

> Available readings and controls depend on the connected BMS, vehicle configuration, permissions, and app connection state. Treat estimates as guidance; the BMS and vehicle hardware remain authoritative.

## Features

### Battery dashboard

- Displays battery state of charge (SOC) and state of health (SOH), along with pack voltage, current, power, and temperature when those values are provided by the connected device.
- Shows charging or discharging status, cell voltage readings, cycle count, and available device metadata.
- Presents battery information in a dashboard designed for at-a-glance use.

### Charging view

- Shows charging status and available charging power information.
- Estimates remaining charging time when the required telemetry is available.
- Uses an animated battery visualization to make charging progress easy to follow.

### BLE connection and garage

- Supports BLE scanning and connection to compatible JK BMS devices.
- Attempts to reconnect after an unexpected disconnection and can automatically connect to a previously selected device.
- Keeps saved vehicle/device entries available in the garage between app launches.
- Connection status is reflected in the interface so readings can be interpreted in context.

### JK BMS controls and safety

- Provides a command service for supported JK BMS operations, including charging and discharging MOSFET controls where supported by the device.
- Applies software interlocks to reduce the risk of changing MOSFET state under unsafe operating conditions, such as while discharge current indicates that the vehicle is under load.
- Hardware commands depend on device support, valid authorization, and a live BLE connection. Confirm device state from returned telemetry where available.

### Remaining range

- Estimates remaining distance using GPS distance travelled and observed SOC consumption when enough reliable trip data is available.
- Uses a configured or observed kilometres-per-SOC estimate as a fallback when trip consumption data is not yet sufficient.
- Filters GPS readings by reported accuracy to avoid treating poor location fixes as reliable distance.
- Range is an estimate and may vary with terrain, speed, load, temperature, riding style, and battery condition.

### Routes and pandal hopping

- Uses Mappls-based route and navigation information for planning and following a pandal-hopping trip.
- Tracks route distance remaining, the next pandal, estimated arrival time, and completed pandals when route data is available.
- Compares the estimated remaining range with the trip distance to help assess whether the planned route appears feasible.
- Map coverage, location permissions, network access, and routing availability can affect these features.

### Profile and preferences

- Includes profile, security, and app/BMS information sections.
- Supports light and dark themes and stores user preferences between sessions.

## How the app is organized

The app separates the interface, application state, BLE communication, protocol handling, and telemetry models. In the current documented structure, the provider coordinates UI state, BLE services manage the device connection, and dedicated parser/command components handle BMS frames and supported writes.

```text
Scooby/
├── lib/
│   ├── core/                 # Shared utilities
│   ├── models/               # Telemetry and device data models
│   ├── parsers/              # JK BMS response parsing
│   ├── providers/            # App, battery, and theme state
│   ├── screens/              # Dashboard, charging, connect, route, profile
│   ├── services/             # BLE lifecycle and BMS commands
│   ├── theme/                # Colors and theme definitions
│   ├── widgets/              # Reusable dashboard components
│   └── main.dart             # App entry point and navigation
├── pubspec.yaml              # Flutter dependencies and assets
└── android/                  # Android platform configuration
```

Names and directories may vary as the project evolves. Refer to the source tree for the current implementation.

## Data and command flow

```text
JK BMS ──BLE notifications──> BLE service ──> frame parser ──> app state ──> screens
Screens ──user action──> app state ──> command service ──BLE write──> JK BMS
GPS / Mappls ──location and route data──> trip and route estimates ──> screens
```

Telemetry is decoded before it is exposed to the dashboard. Commands flow through the app's command layer and are subject to the relevant connection, authorization, and safety checks. GPS and route data support trip estimates and navigation; they do not replace BMS readings.

## BLE and BMS protocol

Scooby communicates with compatible devices over BLE. Device discovery, service and characteristic identifiers, frame layout, authentication, and byte order must match the connected JK BMS model and firmware.

The project notes describe a JK frame header as `55 AA EB 90`, with response categories for settings, cell information, and device information. Verify these details against the parser and captures from the target device before relying on them: JK BMS models and firmware may differ, and protocol constants should not be assumed universal. The implementation may buffer notification chunks and assemble complete frames before parsing.

Do not infer a fixed frame length, register map, authentication value, or checksum algorithm from this overview. Those are implementation- and firmware-specific details. Keep credentials out of ordinary preference storage; use platform-secure storage where credentials must be persisted.

## Range and route estimates

When trip data is available, the range estimator can compare GPS-measured distance with the observed change in SOC to estimate consumption. A kilometres-per-SOC fallback can provide an initial estimate when there is not enough trip history. GPS accuracy filtering helps reject low-quality location updates. Estimates become more useful as reliable trip data accumulates, but they remain approximate.

Route feasibility is a comparison between the estimated remaining range and the distance of the selected route. It should be interpreted as a planning aid, with allowance for conditions that can change energy use or route distance.

## Safety and operating notes

- MOSFET controls affect vehicle hardware. Use them only when the connected device supports the operation and the vehicle is in a safe state.
- Software interlocks reduce risk but cannot guarantee hardware safety or account for every vehicle configuration. Follow the vehicle and BMS manufacturer's guidance.
- BLE readings can be delayed, incomplete, or unavailable during disconnection. Check connection status before acting on displayed values.
- SOC, SOH, charging time, and range are estimates or BMS-reported values; accuracy depends on the device and available data.
- Grant location and Bluetooth permissions only as needed for the features being used.

## Development notes

The documented app uses Flutter, Provider-style state management, and a BLE service layer. The exact packages, platform requirements, build commands, and supported devices should be taken from the current `pubspec.yaml`, platform configuration, and source code rather than assumed from this overview.

When extending the app, keep protocol decoding separate from presentation, handle partial or malformed BLE data safely, serialize device writes as required by the BMS, and ensure the UI reflects confirmed device state where confirmation is available.


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