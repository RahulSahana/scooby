const versionPattern = /^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/;
const defaultDownloadUrl = 'https://github.com/RahulSahana/scooby/releases/latest';

export async function GET() {
  const latestVersion = process.env.SCOOBY_LATEST_VERSION?.trim() ?? '';
  const latestBuildText = process.env.SCOOBY_LATEST_BUILD_NUMBER?.trim() ?? '';
  const latestBuildNumber = /^\d+$/.test(latestBuildText)
    ? Number(latestBuildText)
    : Number.NaN;

  if (!versionPattern.test(latestVersion) ||
      !Number.isSafeInteger(latestBuildNumber) || latestBuildNumber < 0) {
    return Response.json(
      { enabled: false },
      { headers: { 'Cache-Control': 'no-store' } },
    );
  }

  const configuredUrl = process.env.SCOOBY_DOWNLOAD_URL?.trim() ?? '';
  let downloadUrl = defaultDownloadUrl;
  try {
    const parsedUrl = new URL(configuredUrl);
    if (parsedUrl.protocol === 'https:') downloadUrl = parsedUrl.toString();
  } catch {
    // Keep the GitHub Releases page as a safe fallback.
  }

  return Response.json(
    {
      enabled: true,
      latestVersion,
      latestBuildNumber,
      releaseNotes: process.env.SCOOBY_RELEASE_NOTES?.trim() ?? '',
      downloadUrl,
    },
    { headers: { 'Cache-Control': 'no-store' } },
  );
}
