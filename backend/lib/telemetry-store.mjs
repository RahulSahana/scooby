import { createHash, timingSafeEqual } from 'node:crypto';
import { neon } from '@neondatabase/serverless';

let sqlClient;
let schemaReady;

function getSql() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    throw new Error('DATABASE_URL is not configured.');
  }
  sqlClient ??= neon(connectionString);
  return sqlClient;
}

export async function ensureSchema() {
  if (!schemaReady) {
    schemaReady = getSql()`
      CREATE TABLE IF NOT EXISTS scooby_latest_telemetry (
        device_id TEXT PRIMARY KEY,
        access_token_hash CHAR(64) NOT NULL,
        publisher_id TEXT NOT NULL,
        payload JSONB NOT NULL,
        observed_at TIMESTAMPTZ NOT NULL,
        received_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `;
  }
  await schemaReady;
}

function hashAccessToken(token) {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

function tokenMatches(storedHash, suppliedHash) {
  if (typeof storedHash !== 'string' || storedHash.length !== 64) return false;
  const stored = Buffer.from(storedHash, 'hex');
  const supplied = Buffer.from(suppliedHash, 'hex');
  return stored.length === supplied.length && timingSafeEqual(stored, supplied);
}

export async function publishLatest({
  deviceId,
  accessToken,
  publisherId,
  payload,
  observedAt,
}) {
  const sql = getSql();
  const accessTokenHash = hashAccessToken(accessToken);

  await sql`
    INSERT INTO scooby_latest_telemetry (
      device_id,
      access_token_hash,
      publisher_id,
      payload,
      observed_at,
      received_at
    )
    VALUES (
      ${deviceId},
      ${accessTokenHash},
      ${publisherId},
      ${JSON.stringify(payload)}::jsonb,
      ${observedAt},
      NOW()
    )
    ON CONFLICT (device_id) DO NOTHING
  `;

  const updatedRows = await sql`
    UPDATE scooby_latest_telemetry
    SET publisher_id = ${publisherId},
        payload = ${JSON.stringify(payload)}::jsonb,
        observed_at = ${observedAt},
        received_at = NOW()
    WHERE device_id = ${deviceId}
      AND access_token_hash = ${accessTokenHash}
    RETURNING device_id
  `;

  if (updatedRows.length > 0) return true;

  const existing = await sql`
    SELECT access_token_hash
    FROM scooby_latest_telemetry
    WHERE device_id = ${deviceId}
    LIMIT 1
  `;

  // No row indicates a concurrent first registration. A later retry can claim it.
  if (existing.length === 0) return false;
  return tokenMatches(existing[0].access_token_hash, accessTokenHash);
}

export async function readLatest({ deviceId, accessToken }) {
  const sql = getSql();
  const suppliedHash = hashAccessToken(accessToken);
  const rows = await sql`
    SELECT device_id, access_token_hash, publisher_id, payload,
           observed_at, received_at
    FROM scooby_latest_telemetry
    WHERE device_id = ${deviceId}
    LIMIT 1
  `;

  if (rows.length === 0 || !tokenMatches(rows[0].access_token_hash, suppliedHash)) {
    return null;
  }

  const row = rows[0];
  return {
    deviceId: row.device_id,
    publisherId: row.publisher_id,
    payload: row.payload,
    observedAt: new Date(row.observed_at).toISOString(),
    receivedAt: new Date(row.received_at).toISOString(),
  };
}
