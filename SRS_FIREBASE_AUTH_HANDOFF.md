# Scooby Authentication and Shared Telemetry — SRS Handoff

**Document status:** Working handoff  
**Prepared:** 2026-11-01  
**Project:** Scooby Flutter Android app with Vercel API and Upstash Redis

## 1. Purpose

Add an account sign-up/sign-in flow to Scooby, keep each person signed in on their device, and show who last sent the shared scooter telemetry. The app should not ask for login again on every launch. A person signs out explicitly or signs in again after reinstalling the app.

## 2. Users and system parts

- **Scooby user:** signs up or signs in with email and password; their account display name identifies their telemetry uploads.
- **BLE publisher phone:** connects to the JK-BMS and uploads the latest battery reading and scooter location.
- **Remote viewer phone:** reads the shared latest reading from the Scooby API.
- **Firebase Authentication:** stores accounts and maintains the app's signed-in session.
- **Vercel API + Upstash Redis:** accepts uploads and stores the latest shared telemetry snapshot.

## 3. Functional requirements

### Authentication

- **AUTH-01 — First launch:** show Sign in and Create account when there is no signed-in Firebase user.
- **AUTH-02 — Sign-up fields:** require display name, email, and password. Password must be at least 6 characters to match Firebase's current minimum.
- **AUTH-03 — Sign-in:** accept email and password. Do not require email verification in the current flow.
- **AUTH-04 — Persistent session:** Firebase's Android SDK keeps the session across app restarts. The app opens Scooby directly while signed in.
- **AUTH-05 — Sign-out:** Profile provides a Sign out action. It disconnects the local BLE service, stops Scooby's background connection service, and returns to the sign-in screen.
- **AUTH-06 — Auth gate:** BLE connection, telemetry polling, and the main Scooby screens are created only after sign-in.
- **AUTH-07 — Profile name:** Profile edits update the Firebase display name used for future telemetry uploads.

### Shared telemetry and attribution

- **DATA-01 — BLE upload:** while connected to the BMS and receiving valid telemetry, the publisher uploads the latest reading about every 2 minutes.
- **DATA-02 — Remote read:** a signed-in remote viewer reads the existing shared `/api/public-latest` feed on the 2-minute cadence.
- **DATA-03 — Sender attribution:** each published snapshot includes `senderName`; the dashboard displays `Last data sent at <time> by <name>`.
- **DATA-04 — Latest snapshot only:** Redis retains the latest snapshot, not a telemetry history. The current backend has no expiry configured.
- **DATA-05 — Staleness:** Scooby considers server data live for up to 6 minutes; older data is shown as stale.

### Bluetooth and background behavior already in the project

- **BLE-01 — Retry cadence:** disconnected BLE retries run every 10 seconds.
- **BLE-02 — Targeted background scan:** retry scans filter by the saved BMS address and known names (`Scooty`, `JK-BMS`, `JKBMS`) to support screen-off scanning.
- **BLE-03 — Bounded scan:** each 8-second BLE scan has a bounded wait so an open results stream cannot block future retries.
- **SERVER-01 — Separate cadence:** server interaction remains every 2 minutes; the faster BLE retries do not increase server calls.

## 4. Current implementation status

### Implemented in the working tree

- Firebase Core/Auth dependencies were added to `pubspec.yaml` and `pubspec.lock`.
- `lib/screens/auth/auth_screen.dart` contains the email/password sign-in and sign-up UI, including display name capture and user-facing Firebase errors.
- `lib/screens/auth/auth_gate.dart` routes signed-out users to the auth page and creates the battery/navigation providers only for signed-in users.
- `lib/main.dart` initializes Firebase from `DefaultFirebaseOptions.currentPlatform` and uses `AuthGate` as the app entry point.
- Profile shows the Firebase account and offers Sign out; profile name edits update Firebase `displayName`.
- The BLE publisher includes the signed-in display name as `senderName` in telemetry.
- The dashboard displays the last telemetry time and sender name.
- `backend/api/telemetry.mjs` accepts and stores `senderName` in the latest payload, limited to 64 characters.
- BLE retry scanning includes the screen-off filters and timeout handling described above.

### Required before the app can run with Firebase

- `lib/firebase_options.dart` does not exist yet. `flutterfire configure` must generate it for the Firebase project you create.
- The Flutter app has not been built or analyzer-verified with Firebase configuration.
- The backend sender-name change has not been deployed to Vercel. Until deployment, existing deployed code may ignore `senderName`.
- The current Vercel public-latest endpoint remains public. Firebase login controls access to the app UI, but the server does not yet verify Firebase ID tokens. Sender name is descriptive metadata, not a server-verified identity claim.

## 5. Firebase setup — do these steps

1. In [Firebase Console](https://console.firebase.google.com/), create or open the Scooby Firebase project.
2. Open **Build → Authentication → Get started → Sign-in method**. Enable **Email/Password** and save. Email verification is not used by this app flow.
3. Install and log into Firebase CLI if it is not already installed. In a terminal:

   ```powershell
   npm install -g firebase-tools
   firebase login
   ```

4. Activate the FlutterFire CLI:

   ```powershell
   dart pub global activate flutterfire_cli
   ```

5. From the Scooby project folder (`D:\Andro_jects\Scooby`), run:

   ```powershell
   flutterfire configure
   ```

   Select the Scooby Firebase project and **Android**. The Android application ID is `com.example.scooby`. The CLI should create `lib/firebase_options.dart`.

6. Resolve dependencies and build/run the app:

   ```powershell
   flutter pub get
   flutter run
   ```

   If PowerShell says `flutterfire` is not recognized, close and reopen the terminal after activation, or run:

   ```powershell
   dart pub global run flutterfire_cli:flutterfire configure
   ```

7. On the first launch, create an account with a display name. Repeat on Dad's phone with his own email and name. Both signed-in accounts can read the shared scooter feed; the sending account's display name appears with the latest reading.

Firebase's official guides: [Flutter setup](https://firebase.google.com/docs/flutter/setup), [Flutter Authentication](https://firebase.google.com/docs/auth/flutter/start), and [email/password sign-in](https://firebase.google.com/docs/auth/flutter/password-auth).

## 6. Backend deployment needed for sender names

After Firebase setup and a local app check:

1. Push the Scooby repository changes to GitHub.
2. Confirm Vercel deploys the `backend` root project.
3. Confirm a fresh telemetry upload appears on Dad's dashboard with `Last data sent at <time> by <account name>`.

Do not add Firebase service-account private keys to Flutter or GitHub. The present backend does not need a service-account key because it has not yet been changed to verify Firebase ID tokens.

## 7. Acceptance checks

- Signed-out install opens the auth screen and does not start BLE scanning or remote polling.
- Create an account using a display name; Scooby opens the connection flow without asking for email verification.
- Force-close and reopen Scooby; the account stays signed in and opens the connection flow.
- Sign out from Profile; Scooby disconnects BLE/stops its background service and returns to auth.
- Reinstall the app; sign-in is requested again, then the existing account can be used.
- Phone A signs in, connects to the BMS, and uploads. Phone B signs in and reads the shared feed. The dashboard shows the upload time and Phone A account name.
- Lock the BLE publisher phone and verify that its foreground notification remains visible and telemetry continues. Results can vary with Android/Xiaomi battery restrictions.
- Confirm BLE retries remain 10 seconds and server requests remain 2 minutes.

## 8. Known limitations and future scope

- The shared telemetry feed is intentionally public in the current backend. Anyone who knows the endpoint can read the latest battery telemetry and scooter location.
- Firebase accounts currently gate the app locally; Vercel does not validate Firebase tokens or enforce account ownership. If account-level privacy or access control becomes a requirement, add Firebase ID-token verification to Vercel and define which accounts belong to the shared scooter.
- There is no telemetry history, password-reset UI, or account-deletion UI in this implementation.
- Flutter package resolution updated the lockfile, but the Dart tool reported an access-denied telemetry-session file in the host profile. The Firebase config file is still needed before a full build/analyze check.
