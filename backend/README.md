# Scooby telemetry API

This folder is a Vercel project for Scooby's small, latest-reading API. It stores one current telemetry snapshot per scooter, including the location supplied by the phone connected to its JK-BMS. It does not keep an unbounded history.

## API

- `POST /api/telemetry` publishes the latest battery reading and optional GPS position.
- `GET /api/latest?deviceId=...` returns the latest reading and both the phone-observed and server-received timestamps.
- `GET /api/public-latest` returns the app's public latest battery/location snapshot without authentication.
- `GET /api/app-update` returns public update information for the Flutter app. It returns `enabled: false` until update metadata is configured.

`POST /api/telemetry` and `GET /api/latest` require `Authorization: Bearer <publisher-token>`. A phone connected to the BMS publishes telemetry. Scooby reads the public snapshot automatically when its phone is not connected to the BMS. The public endpoint exposes the latest battery telemetry and scooter location to anyone who can reach it; it is intended for this single shared scooter. The app update endpoint is also public and contains release metadata.

## Deploy with Vercel and Upstash

1. Push this folder to the Scooby GitHub repository.
2. Import the repository into Vercel and set **Root Directory** to `backend`.
3. Create a free Redis database in Upstash, or add the Upstash Redis integration from the Vercel Marketplace. Add `UPSTASH_REDIS_REST_URL` and `UPSTASH_REDIS_REST_TOKEN` to the Vercel project's Production environment variables.
4. Deploy the project. The API stores only the latest snapshot per scooter in Redis.
5. Set the deployed API base URL in the Flutter app. Do not put a shared token in source code or a compile-time environment variable.

## Public scooter feed

Each phone generates a separate server device ID and token locally and stores them in platform-secure storage. This lets more than one phone publish for the same BMS without copying tokens between phones. The server ties the shared feed to the BMS publisher identity and serves its latest accepted reading to Scooby installs. Remote-reader phones need no pairing action or account.

`observedAt` is sent by the phone, while `receivedAt` is assigned by the server; clients use the latter to decide whether a value is stale. Keep the two-minute publish/read cadence to limit Redis usage.

## App update banner

The Flutter app checks `/api/app-update` when the connection screen and dashboard open. Configure these environment variables for the **Production** environment in the Vercel project to publish an update notice:

- `SCOOBY_LATEST_VERSION`: app version, such as `3.0.2`.
- `SCOOBY_LATEST_BUILD_NUMBER`: Flutter build number from the `+` part of `pubspec.yaml`, such as `4` for `3.0.2+4`.
- `SCOOBY_RELEASE_NOTES`: short text shown in the banner.
- `SCOOBY_DOWNLOAD_URL`: HTTPS link to the GitHub release or APK download. If omitted or invalid, the banner opens the GitHub Releases page.

After setting or changing these values, redeploy the Vercel project. Attach the APK to the GitHub release so Android users can download and install it. The banner only notifies and opens the download page; Android still asks the user to confirm installation. Dismissal is remembered for that announced version, and a notice appears again when a newer version is published.
