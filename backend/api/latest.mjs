import { readLatest } from '../lib/telemetry-store.mjs';

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

export async function GET(request) {
  const url = new URL(request.url);
  const deviceId = url.searchParams.get('deviceId');
  const accessToken = bearerToken(request);

  if (!deviceId || !/^[A-Za-z0-9_-]{16,80}$/.test(deviceId)) {
    return json({ error: 'A valid deviceId is required.' }, 400);
  }
  if (!accessToken) return json({ error: 'A valid Scooby pairing token is required.' }, 401);

  try {
    const reading = await readLatest({ deviceId, accessToken });
    if (!reading) return json({ error: 'Scooter was not found or is not shared with this phone.' }, 404);
    return json(reading);
  } catch (error) {
    console.error('Scooby latest telemetry read failed:', error);
    return json({ error: 'Telemetry is temporarily unavailable.' }, 503);
  }
}
