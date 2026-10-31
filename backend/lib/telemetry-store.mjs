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

const publicDeviceKey = 'scooby:public:device';
const publicPublisherKey = 'scooby:public:publisher';
const publicLatestKey = 'scooby:public:latest';

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
  let accepted = false;
  if (!existing) {
    const created = await redis.set(key, record, { nx: true });
    if (created === 'OK') {
      accepted = true;
    } else {
      existing = await getRecord(redis, key);
    }
  }

  if (!accepted) {
    if (!existing || !tokenMatches(existing.accessTokenHash, accessTokenHash)) {
      return false;
    }
    await redis.set(key, record);
  }

  let publicPublisherId = await redis.get(publicPublisherKey);
  if (publicPublisherId == null) {
    // Migrate the original single-phone feed owner without interrupting it.
    const legacyDeviceId = await redis.get(publicDeviceKey);
    if (typeof legacyDeviceId === 'string') {
      const legacyRecord = await getRecord(redis, keyFor(legacyDeviceId));
      if (typeof legacyRecord?.publisherId === 'string') {
        const claimed = await redis.set(
          publicPublisherKey,
          legacyRecord.publisherId,
          { nx: true },
        );
        publicPublisherId = claimed === 'OK'
          ? legacyRecord.publisherId
          : await redis.get(publicPublisherKey);
      }
    }
  }

  if (publicPublisherId == null) {
    const claimed = await redis.set(publicPublisherKey, publisherId, { nx: true });
    publicPublisherId = claimed === 'OK'
      ? publisherId
      : await redis.get(publicPublisherKey);
  }

  // Multiple phones may publish for this same BMS, each with its own token.
  // Only the publisher identity for this scooter can update the shared feed.
  if (publicPublisherId === publisherId) {
    await redis.set(publicLatestKey, {
      payload,
      observedAt,
      receivedAt: record.receivedAt,
    });
  }

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

export async function readPublicLatest() {
  const redis = getRedis();
  const record = await getRecord(redis, publicLatestKey);
  if (!record || !record.payload || !record.receivedAt) return null;

  return {
    payload: record.payload,
    observedAt: record.observedAt,
    receivedAt: record.receivedAt,
  };
}
