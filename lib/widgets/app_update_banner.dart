import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/app_update_service.dart';
import '../theme/app_colors.dart';

class AppUpdateBanner extends StatefulWidget {
  const AppUpdateBanner({super.key});

  @override
  State<AppUpdateBanner> createState() => _AppUpdateBannerState();
}

class _AppUpdateBannerState extends State<AppUpdateBanner> {
  AppUpdateRelease? _release;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final release = await const AppUpdateService().checkForUpdate();
    if (!mounted || release == null) return;
    String? dismissedVersion;
    try {
      final preferences = await SharedPreferences.getInstance();
      dismissedVersion = preferences.getString('scooby.dismissedUpdateVersion');
    } catch (_) {
      // If local preferences are unavailable, show the update notice anyway.
    }
    if (!mounted) return;
    setState(() {
      _release = release;
      _dismissed = dismissedVersion == release.version;
    });
  }

  Future<void> _dismissUpdate() async {
    final release = _release;
    setState(() => _dismissed = true);
    if (release == null) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        'scooby.dismissedUpdateVersion',
        release.version,
      );
    } catch (_) {
      // Keep the banner dismissed for this screen if saving fails.
    }
  }

  Future<void> _openUpdate() async {
    final release = _release;
    if (release == null) return;

    try {
      final opened = await launchUrl(
        release.downloadUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened || !mounted) return;
    } catch (_) {
      if (!mounted) return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the update page.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final release = _release;
    if (release == null || _dismissed) return const SizedBox.shrink();

    final appColors = Theme.of(context).extension<AppColors>();
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.primary;
    final primaryText = appColors?.primaryText ?? colorScheme.onSurface;
    final secondaryText =
        appColors?.secondaryText ?? colorScheme.onSurfaceVariant;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.system_update_alt, color: accent, size: 21),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Scooby update available · v${release.version}',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss update notice',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  onPressed: _dismissUpdate,
                  icon: Icon(Icons.close, color: secondaryText, size: 19),
                ),
              ],
            ),
            if (release.releaseNotes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 30, right: 8, bottom: 2),
                child: Text(
                  release.releaseNotes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 12,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _openUpdate,
                icon: const Icon(Icons.open_in_new, size: 17),
                label: const Text('View update'),
                style: TextButton.styleFrom(
                  foregroundColor: accent,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
