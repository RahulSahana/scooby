import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

class BatteryAlertSettingsCard extends StatefulWidget {
  const BatteryAlertSettingsCard({super.key});

  @override
  State<BatteryAlertSettingsCard> createState() =>
      _BatteryAlertSettingsCardState();
}

class _BatteryAlertSettingsCardState
    extends State<BatteryAlertSettingsCard> {
  static const _enabledKey = 'charging_alert_enabled';
  static const _thresholdKey = 'charging_alert_threshold';

  bool _enabled = false;
  int _threshold = 80;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _enabled = prefs.getBool(_enabledKey) ?? false;
      _threshold = prefs.getInt(_thresholdKey) ?? 80;
      _loading = false;
    });
  }

  Future<void> _setEnabled(bool enabled) async {
    if (enabled) {
      final permissionGranted =
      await NotificationService.instance.requestPermission();

      if (!permissionGranted) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Allow notifications in your phone settings to use battery alerts.',
            ),
          ),
        );
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);

    if (!mounted) return;
    setState(() => _enabled = enabled);
  }

  Future<void> _setThreshold(int threshold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_thresholdKey, threshold);

    if (!mounted) return;
    setState(() => _threshold = threshold);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Battery notifications',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Charging alert'),
              subtitle: const Text('Notify me when charging reaches my limit'),
              value: _enabled,
              onChanged: _setEnabled,
            ),
            if (_enabled) ...[
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notify at'),
                trailing: DropdownButton<int>(
                  value: _threshold,
                  items: const [0,15,25,40,50,70, 80, 90, 100]
                      .map(
                        (value) => DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value%'),
                    ),
                  )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      _setThreshold(value);
                    }
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}