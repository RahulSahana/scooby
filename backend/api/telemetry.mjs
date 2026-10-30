import { publishLatest } from '../lib/telemetry-store.mjs';

function json(body, status = 200) {
  return Response.json(body, {
    status,
    headers: { 'Cache-Control': 'no-store' },
  });
}

function bearerToken(request) {
  const value = request.headers.get('authorization') ?? '';
  const match = /^Bearer ([A-Za-z0-9_-]{32,128})$/.exec(value);
  return match?.[1] ?? null;
}

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function isFiniteNumber(value) {
  return typeof value === 'number' && Number.isFinite(value);
}

function validTelemetry(body) {
  if (!isObject(body.battery)) return false;
  const battery = body.battery;
  if (!isFiniteNumber(battery.voltage) || battery.voltage < 0 || battery.voltage > 200) return false;
  if (!isFiniteNumber(battery.current) || battery.current < -1000 || battery.current > 1000) return false;
  if (!Number.isInteger(battery.soc) || battery.soc < 0 || battery.soc > 100) return false;
  if (!isFiniteNumber(battery.temperature) || battery.temperature < -50 || battery.temperature > 150) return false;
  if (battery.cellVoltages !== undefined &&
      (!Array.isArray(battery.cellVoltages) ||
       battery.cellVoltages.length > 64 ||
       !battery.cellVoltages.every((value) => isFiniteNumber(value) && value >= 0 && value <= 10))) {
    return false;
  }

  if (body.location !== null && body.location !== undefined) {
    if (!isObject(body.location) ||
        !isFiniteNumber(body.location.latitude) ||
        body.location.latitude < -90 || body.location.latitude > 90 ||
        !isFiniteNumber(body.location.longitude) ||
        body.location.longitude < -180 || body.location.longitude > 180) {
      return false;
    }
  }

  return true;
}

export async function POST(request) {
  const accessToken = bearerToken(request);
  if (!accessToken) return json({ error: 'A valid Scooby pairing token is required.' }, 401);

  let body;
  try {
    body = await request.json();
  } catch {
    return json({ error: 'Request body must be valid JSON.' }, 400);
  }

  if (!isObject(body) ||
      typeof body.deviceId !== 'string' || !/^[A-Za-z0-9_-]{16,80}$/.test(body.deviceId) ||
      typeof body.publisherId !== 'string' || !/^[A-Za-z0-9_-]{8,80}$/.test(body.publisherId) ||
      !validTelemetry(body)) {
    return json({ error: 'Telemetry payload is incomplete or invalid.' }, 400);
  }

  const parsedObservedAt = body.observedAt === undefined
    ? new Date()
    : new Date(body.observedAt);
  if (Number.isNaN(parsedObservedAt.getTime())) {
    return json({ error: 'observedAt must be a valid timestamp.' }, 400);
  }

  const payload = {
    battery: {
      voltage: body.battery.voltage,
      current: body.battery.current,
      soc: body.battery.soc,
      temperature: body.battery.temperature,
      ...(isFiniteNumber(body.battery.power) ? { power: body.battery.power } : {}),
      ...(isFiniteNumber(body.battery.range) ? { range: body.battery.range } : {}),
      ...(Number.isInteger(body.battery.cycleCount) ? { cycleCount: body.battery.cycleCount } : {}),
      ...(Array.isArray(body.battery.cellVoltages) ? { cellVoltages: body.battery.cellVoltages } : {}),
      ...(typeof body.battery.isCharging === 'boolean' ? { isCharging: body.battery.isCharging } : {}),
      ...(typeof body.battery.isDischarging === 'boolean' ? { isDischarging: body.battery.isDischarging } : {}),
    },
    location: body.location ?? null,
  };

  try {
    const accepted = await publishLatest({
      deviceId: body.deviceId,
      accessToken,
      publisherId: body.publisherId,
      payload,
      observedAt: parsedObservedAt.toISOString(),
    });
    if (!accepted) return json({ error: 'Pairing token does not match this scooter.' }, 403);
    return json({ ok: true, receivedAt: new Date().toISOString() });
  } catch (error) {
    console.error('Scooby telemetry publish failed:', error);
    return json({ error: 'Telemetry is temporarily unavailable.' }, 503);
  }
}
