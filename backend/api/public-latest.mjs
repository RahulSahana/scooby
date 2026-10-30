import { readPublicLatest } from '../lib/telemetry-store.mjs';

export async function GET() {
  try {
    const reading = await readPublicLatest();
    if (!reading) {
      return Response.json(
        { error: 'No Scooby telemetry has been published yet.' },
        {
          status: 404,
          headers: { 'Cache-Control': 'public, s-maxage=10' },
        },
      );
    }

    return Response.json(reading, {
      headers: {
        'Cache-Control': 'public, s-maxage=10, stale-while-revalidate=30',
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
