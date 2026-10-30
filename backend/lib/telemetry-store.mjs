import { createHash, timingSafeEqual } from 'node:crypto';
import { Redis } from '@upstash/redis';

let redisClient;

function getRedis() {
  if (!process.env.UPSTASH_REDIS_REST_URL || !process.env.UPSTASH_REDIS_REST_TOKEN) {
    throw new Error('Upstash Redis environment variables are not configured.');
  }
  redisClient ??= Redis.fromEnv();
  return redisClient;
}

function keyFor(deviceId) {
  return `scooby:latest:${deviceId}`;
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

async function getRecord(redis, key) {
  const value = await redis.get(key);
  if (typeof value === 'string') {
    try {
      return JSON.parse(value);
    } catch {
      return null;
    }
  }
  return value && typeof value === 'object' ? value : null;
}

export async function publishLatest({
  deviceId,
  accessToken,
  publisherId,
  payload,
  observedAt,
}) {
  const redis = getRedis();
  const key = keyFor(deviceId);
  const accessTokenHash = hashAccessToken(accessToken);
  const record = {
    accessTokenHash,
    deviceId,
    publisherId,
    payload,
    observedAt,
    receivedAt: new Date().toISOString(),
  };

  let existing = await getRecord(redis, key);
  if (!existing) {
    const created = await redis.set(key, record, { nx: true });
    if (created === 'OK') return true;
    existing = await getRecord(redis, key);
  }

  if (!existing || !tokenMatches(existing.accessTokenHash, accessTokenHash)) return false;
  await redis.set(key, record);
  return true;
}

export async function readLatest({ deviceId, accessToken }) {
  const redis = getRedis();
  const record = await getRecord(redis, keyFor(deviceId));
  const suppliedHash = hashAccessToken(accessToken);
  if (!record || !tokenMatches(record.accessTokenHash, suppliedHash)) return null;

  const { accessTokenHash: _accessTokenHash, ...publicRecord } = record;
  return publicRecord;
}
