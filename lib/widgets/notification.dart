import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';
import '../theme/app_colors.dart';

class NotificationSettingsCard extends StatefulWidget {
  const NotificationSettingsCard({super.key});

  @override
  State<NotificationSettingsCard> createState() =>
      _NotificationSettingsCardState();
}

class _NotificationSettingsCardState
    extends State<NotificationSettingsCard> {
  static const _batteryEnabledKey = 'battery_percent_alert_enabled';
  static const _batteryThresholdKey = 'battery_percent_alert_threshold';

  static const _rangeEnabledKey = 'range_alert_enabled';
  static const _rangeThresholdKey = 'range_alert_threshold_km';

  static const _temperatureEnabledKey = 'temperature_alert_enabled';
  static const _temperatureThresholdKey =
      'temperature_alert_threshold_c';

  static const _disconnectEnabledKey = 'disconnect_alert_enabled';

  bool _batteryEnabled = false;
  int _batteryThreshold = 80;

  bool _rangeEnabled = false;
  int _rangeThreshold = 10;

  bool _temperatureEnabled = false;
  int _temperatureThreshold = 50;

  bool _disconnectEnabled = false;
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
      _batteryEnabled = prefs.getBool(_batteryEnabledKey) ?? false;
      _batteryThreshold = prefs.getInt(_batteryThresholdKey) ?? 80;

      _rangeEnabled = prefs.getBool(_rangeEnabledKey) ?? false;
      _rangeThreshold = prefs.getInt(_rangeThresholdKey) ?? 10;

      _temperatureEnabled =
          prefs.getBool(_temperatureEnabledKey) ?? false;
      _temperatureThreshold =
          prefs.getInt(_temperatureThresholdKey) ?? 50;

      _disconnectEnabled =
          prefs.getBool(_disconnectEnabledKey) ?? false;

      _loading = false;
    });
  }

  Future<void> _setEnabled({
    required bool enabled,
    required String preferenceKey,
    required void Function(bool value) updateState,
  }) async {
    if (enabled) {
      final permissionGranted =
      await NotificationService.instance.requestPermission();

      if (!permissionGranted) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Allow notifications in your phone settings to enable alerts.',
            ),
          ),
        );
        return;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(preferenceKey, enabled);

    if (!mounted) return;
    setState(() => updateState(enabled));
  }

  Future<void> _setThreshold({
    required int threshold,
    required String preferenceKey,
    required void Function(int value) updateState,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(preferenceKey, threshold);

    if (!mounted) return;
    setState(() => updateState(threshold));
  }

  Widget _buildAlertSwitch({
    required AppColors colors,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: colors.primary),
      title: Text(
        title,
        style: TextStyle(
          color: colors.primaryText,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: colors.secondaryText),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildThresholdRow({
    required AppColors colors,
    required String label,
    required int value,
    required List<int> options,
    required String suffix,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 48, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colors.secondaryText),
            ),
          ),
          DropdownButton<int>(
            value: value,
            dropdownColor: colors.cardColor,
            style: TextStyle(
              color: colors.primaryText,
              fontSize: 14,
            ),
            items: options
                .map(
                  (option) => DropdownMenuItem<int>(
                value: option,
                child: Text('$option$suffix'),
              ),
            )
                .toList(),
            onChanged: (selected) {
              if (selected != null) onChanged(selected);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 4,
          ),
          childrenPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          leading: Icon(
            Icons.notifications_active_outlined,
            color: colors.primary,
          ),
          title: Text(
            'Notifications',
            style: TextStyle(
              color: colors.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            'Choose which scooter alerts Scooby should send.',
            style: TextStyle(
              color: colors.secondaryText,
              fontSize: 13,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAlertSwitch(
                    colors: colors,
                    icon: Icons.battery_charging_full,
                    title: 'Battery percentage',
                    subtitle: 'Alert when charging reaches your selected limit',
                    value: _batteryEnabled,
                    onChanged: (value) => _setEnabled(
                      enabled: value,
                      preferenceKey: _batteryEnabledKey,
                      updateState: (enabled) => _batteryEnabled = enabled,
                    ),
                  ),
                  if (_batteryEnabled)
                    _buildThresholdRow(
                      colors: colors,
                      label: 'Notify at',
                      value: _batteryThreshold,
                      options: const [50, 60, 70, 80, 90, 100],
                      suffix: '%',
                      onChanged: (value) => _setThreshold(
                        threshold: value,
                        preferenceKey: _batteryThresholdKey,
                        updateState: (threshold) =>
                        _batteryThreshold = threshold,
                      ),
                    ),

                  Divider(color: colors.cardBorder),

                  _buildAlertSwitch(
                    colors: colors,
                    icon: Icons.route_outlined,
                    title: 'Remaining range',
                    subtitle: 'Alert when estimated range gets low',
                    value: _rangeEnabled,
                    onChanged: (value) => _setEnabled(
                      enabled: value,
                      preferenceKey: _rangeEnabledKey,
                      updateState: (enabled) => _rangeEnabled = enabled,
                    ),
                  ),
                  if (_rangeEnabled)
                    _buildThresholdRow(
                      colors: colors,
                      label: 'Notify below',
                      value: _rangeThreshold,
                      options: const [5, 10, 15, 20, 25, 30, 40, 50],
                      suffix: ' km',
                      onChanged: (value) => _setThreshold(
                        threshold: value,
                        preferenceKey: _rangeThresholdKey,
                        updateState: (threshold) => _rangeThreshold = threshold,
                      ),
                    ),

                  Divider(color: colors.cardBorder),

                  _buildAlertSwitch(
                    colors: colors,
                    icon: Icons.device_thermostat,
                    title: 'Temperature',
                    subtitle: 'Alert when battery temperature gets high',
                    value: _temperatureEnabled,
                    onChanged: (value) => _setEnabled(
                      enabled: value,
                      preferenceKey: _temperatureEnabledKey,
                      updateState: (enabled) => _temperatureEnabled = enabled,
                    ),
                  ),
                  if (_temperatureEnabled)
                    _buildThresholdRow(
                      colors: colors,
                      label: 'Notify above',
                      value: _temperatureThreshold,
                      options: const [35, 40, 45, 50, 55, 60],
                      suffix: '°C',
                      onChanged: (value) => _setThreshold(
                        threshold: value,
                        preferenceKey: _temperatureThresholdKey,
                        updateState: (threshold) =>
                        _temperatureThreshold = threshold,
                      ),
                    ),

                  Divider(color: colors.cardBorder),

                  _buildAlertSwitch(
                    colors: colors,
                    icon: Icons.bluetooth_disabled,
                    title: 'Scooby disconnected',
                    subtitle: 'Alert when the scooter loses its Bluetooth link',
                    value: _disconnectEnabled,
                    onChanged: (value) => _setEnabled(
                      enabled: value,
                      preferenceKey: _disconnectEnabledKey,
                      updateState: (enabled) => _disconnectEnabled = enabled,
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'Custom notifications can be added later.',
                    style: TextStyle(
                      color: colors.secondaryText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}