import { readPublicLatest } from '../lib/telemetry-store.mjs';

export async function GET() {
  try {
    const reading = await readPublicLatest();
    if (!reading) {
      return Response.json(
        { error: 'No Scooby telemetry has been published yet.' },
        {
          status: 404,
          headers: { 'Cache-Control': 'no-store' },
        },
      );
    }

    return Response.json(reading, {
      headers: {
        'Cache-Control': 'no-store',
      },
    });
  } catch (error) {
    console.error('Scooby public telemetry read failed:', error);
    return Response.json(
      { error: 'Telemetry is temporarily unavailable.' },
      {
        status: 503,
        headers: { 'Cache-Control': 'no-store' },
      },
    );
  }
}
