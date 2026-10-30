# Scooby telemetry API

This folder is a Vercel project for Scooby's small, latest-reading API. It stores one current telemetry snapshot per scooter, including the location supplied by the phone connected to its JK-BMS. It does not keep an unbounded history.

## API

- `POST /api/telemetry` publishes the latest battery reading and optional GPS position.
- `GET /api/latest?deviceId=...` returns the latest reading and both the phone-observed and server-received timestamps.

Both endpoints require `Authorization: Bearer <pairing-token>`. The first successful upload claims the device ID and token. The server stores only a SHA-256 hash of the token. A phone that has been paired with the scooter can read the latest value and can publish when it connects to the BMS over Bluetooth.

## Deploy with Vercel and Upstash

1. Push this folder to the Scooby GitHub repository.
2. Import the repository into Vercel and set **Root Directory** to `backend`.
3. Create a free Redis database in Upstash, or add the Upstash Redis integration from the Vercel Marketplace. Add `UPSTASH_REDIS_REST_URL` and `UPSTASH_REDIS_REST_TOKEN` to the Vercel project's Production environment variables.
4. Deploy the project. The API stores only the latest snapshot per scooter in Redis.
5. Set the deployed API base URL in the Flutter app. Do not put a shared token in source code or a compile-time environment variable.

## Pairing and client secrets

The Flutter app must generate a random device ID, a random pairing token with at least 32 URL-safe characters, and a random publisher-session ID. Keep the pairing token in platform-secure storage. The first phone creates the scooter's shared identity; other authorized phones receive the device ID and token through a one-time QR/pairing flow. Every authorized phone can then read the server snapshot and publish if it obtains the local BLE connection.

The API only accepts HTTPS in production. `observedAt` is sent by the phone, while `receivedAt` is assigned by the server; clients should use the latter to decide whether a value is stale. The Upstash Free plan currently includes 500,000 commands per month. At a two-minute cadence, one publisher and one remote reader use roughly 64,800 Redis commands per 30-day month (three commands per cycle), excluding occasional setup or retries. Keep within the free-plan quota; do not upgrade to a paid plan if the project must remain free.
