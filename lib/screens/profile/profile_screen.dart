import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/battery_provider.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/notification.dart';
const String latestReleaseUrl =
    'https://github.com/OWNER/REPOSITORY/releases/latest';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  late final TextEditingController _passwordController;

  String _userName = 'Rahul Sahana';
  String _userDesc = 'West Bengal • App Developer';
  String _userAvatar = '🤖';
  String _appVersion = 'Loading...';

  final List<String> _avatarOptions = [
    '🤖',
    '👽',
    '🦊',
    '🐶',
    '🚀',
    '⚡',
    '👾',
    '🏍️',
  ];

  @override
  void initState() {
    super.initState();

    final password = context.read<BatteryProvider>().bmsPassword;
    _passwordController = TextEditingController(text: password);

    _loadProfileData();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();

    if (!mounted) return;

    setState(() {
      _userName = prefs.getString('profile_name') ?? 'Rahul Sahana';
      _userDesc =
          prefs.getString('profile_desc') ?? 'West Bengal • EV Developer';
      _userAvatar = prefs.getString('profile_avatar') ?? '🤖';
      _appVersion = 'v${packageInfo.version}';
    });
  }

  Future<void> _saveProfileData(
      String name,
      String desc,
      String avatar,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('profile_name', name);
    await prefs.setString('profile_desc', desc);
    await prefs.setString('profile_avatar', avatar);

    if (!mounted) return;

    setState(() {
      _userName = name;
      _userDesc = desc;
      _userAvatar = avatar;
    });
  }

  String _formatFirstOnDate(String date) {
    if (date.length != 6) return date;

    final year = 2000 + int.parse(date.substring(0, 2));
    final month = date.substring(2, 4);
    final day = date.substring(4, 6);

    return '$day/$month/$year';
  }

  Future<void> _showEditProfileDialog() async {
    final nameController = TextEditingController(text: _userName);
    final descController = TextEditingController(text: _userDesc);
    String selectedAvatar = _userAvatar;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final primary = Theme.of(dialogContext).colorScheme.primary;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text('Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Choose an Avatar'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _avatarOptions.map((avatar) {
                        final isSelected = avatar == selectedAvatar;

                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedAvatar = avatar;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primary.withValues(alpha: 0.15)
                                  : Colors.grey.withValues(alpha: 0.1),
                              border: Border.all(
                                color: isSelected
                                    ? primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              avatar,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      decoration: InputDecoration(
                        labelText: 'Tagline',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor:
                    Theme.of(dialogContext).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await _saveProfileData(
                      nameController.text.trim(),
                      descController.text.trim(),
                      selectedAvatar,
                    );

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descController.dispose();
  }

  Future<void> _showSwitchScooterModal(
      BuildContext context,
      BatteryProvider provider,
      ) async {
    provider.bleService.disconnect();
    provider.bleService.startScan();

    Timer? refreshTimer;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            refreshTimer ??= Timer.periodic(
              const Duration(seconds: 1),
                  (_) {
                if (sheetContext.mounted) {
                  setModalState(() {});
                }
              },
            );

            final devices = provider.bleService.devices;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nearby Scooters',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      devices.isEmpty
                          ? 'Scanning for scooters...'
                          : 'Select a scooter to connect.',
                    ),
                    const SizedBox(height: 16),
                    if (devices.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          final name = device.platformName.isEmpty
                              ? 'Unknown Scooter'
                              : device.platformName;

                          return ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                Icons.electric_bike,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: Text(name),
                            subtitle: Text(device.remoteId.str),
                            onTap: () {
                              Navigator.pop(context);
                              provider.bleService.stopScan();
                              provider.bleService.connect(device);
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    refreshTimer?.cancel();
    provider.bleService.stopScan();
  }

  Widget _sectionLabel(String title, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: colors.secondaryText,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.3,
        ),
      ),
    );
  }

  Widget _panel({
    required AppColors colors,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.cardBorder),
      ),
      child: child,
    );
  }

  Widget _buildHardwareRow(
      BuildContext context,
      AppColors colors,
      String label,
      String value, {
        bool isHighlight = false,
        bool isCopyable = false,
      }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colors.primaryText.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ),
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isHighlight
                        ? colors.primary
                        : colors.primaryText,
                    fontSize: 14,
                    fontWeight:
                    isHighlight ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (isCopyable) ...[
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  iconSize: 16,
                  tooltip: 'Copy $label',
                  icon: Icon(
                    Icons.copy,
                    size: 16,
                    color: colors.primaryText.withValues(alpha: 0.6),
                  ),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: value),
                    );

                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label copied to clipboard'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor:
                        Theme.of(context).colorScheme.primary,
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final batteryProvider = context.watch<BatteryProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final battery = batteryProvider.batteryData;
    final colors = Theme.of(context).extension<AppColors>()!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _userAvatar,
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.primaryText,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _userDesc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.primaryText.withValues(alpha: 0.65),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit profile',
                  icon: Icon(Icons.edit, color: scheme.primary),
                  onPressed: _showEditProfileDialog,
                ),
              ],
            ),
            const SizedBox(height: 28),
//==============================================================
          /// APPEARANCE
//==============================================================
            _sectionLabel('Appearance', colors),
            _panel(
              colors: colors,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  themeProvider.isDarkMode ? 'Dark Mode' : 'Light Mode',
                  style: TextStyle(
                    color: colors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'Switch between light and dark themes',
                  style: TextStyle(color: colors.secondaryText),
                ),
                secondary: Icon(
                  themeProvider.isDarkMode
                      ? Icons.dark_mode
                      : Icons.light_mode_rounded,
                  color: scheme.primary,
                ),
                value: themeProvider.isDarkMode,
                onChanged: (_) => themeProvider.toggleTheme(),
              ),
            ),
            const SizedBox(height: 28),
            _sectionLabel('Notifications', colors),
//==============================================================
            /// Notifications
//==============================================================
            const NotificationSettingsCard(),
            const SizedBox(height: 28),

            _sectionLabel('My Garage', colors),
            _panel(
              colors: colors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Primary Scooter',
                    style: TextStyle(
                      color: colors.primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The app will prioritize connecting to this scooter.',
                    style: TextStyle(color: colors.secondaryText),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: batteryProvider.primaryScooterId,
                      dropdownColor: colors.cardColor,
                      style: TextStyle(color: colors.primaryText),
                      hint: const Text('No vehicles saved'),
                      icon: Icon(Icons.electric_bike, color: scheme.primary),
                      items: batteryProvider.savedGarage.map((scooter) {
                        return DropdownMenuItem<String>(
                          value: scooter['id'],
                          child: Text(scooter['name'] ?? 'Scooter'),
                        );
                      }).toList(),
                      onChanged: (newId) {
                        if (newId != null) {
                          batteryProvider.setPrimaryScooter(newId);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
//***************************************************
            ///          BMS SECURITY
//***************************************************
            _sectionLabel('BMS Security', colors),
            _panel(
              colors: colors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Device Password',
                    style: TextStyle(
                      color: colors.primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Used when sending hardware commands.',
                    style: TextStyle(color: colors.secondaryText),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _passwordController,
                          style: TextStyle(color: colors.primaryText),
                          decoration: InputDecoration(
                            hintText: 'Enter BMS password',
                            filled: true,
                            fillColor: colors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          batteryProvider.setBmsPassword(
                            _passwordController.text,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password updated'),
                            ),
                          );
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

//==============================================================
//                         LATEST RELEASE
//==============================================================
            _sectionLabel('Latest Release', colors),
            _panel(
              colors: colors,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Download latest APK',
                  style: TextStyle(
                    color: colors.primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  'View or download the latest Scooby release',
                  style: TextStyle(color: colors.secondaryText),
                ),
                leading: Icon(
                  Icons.system_update_rounded,
                  color: scheme.primary,
                ),
                trailing: Icon(
                  Icons.open_in_new_rounded,
                  color: colors.secondaryText,
                ),
                onTap: () async {
                  final uri = Uri.parse(
                    'https://github.com/OWNER/REPOSITORY/releases/latest',
                  );

                  final opened = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );

                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not open the release link.'),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 28),

//***************************************************
            ///          ABOUT BMS
//***************************************************
            _sectionLabel('About BMS', colors),
            _panel(
              padding: const EdgeInsets.all(20),
              colors: colors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildHardwareRow(
                    context,
                    colors,
                    'Vendor ID',
                    battery.vendorId,
                    isHighlight: true,
                    isCopyable: true,
                  ),
                  //const SizedBox(height: 12),
                  _buildHardwareRow(
                    context,
                    colors,
                    'Serial No.',
                    battery.serialNumber,
                    isCopyable: true,
                  ),
                  //const SizedBox(height: 12),
                  _buildHardwareRow(
                    context,
                    colors,
                    'Hardware Ver.',
                    battery.hardwareVersion,
                  ),
                  const SizedBox(height: 12),
                  _buildHardwareRow(
                    context,
                    colors,
                    'App Version',
                    _appVersion,
                  ),
                  const SizedBox(height: 12),
                  _buildHardwareRow(
                    context,
                    colors,
                    'First On Date',
                    _formatFirstOnDate(battery.firstOnDate),
                  ),
                  const SizedBox(height: 12),
                  _buildHardwareRow(
                    context,
                    colors,
                    'Total Uptime',
                    battery.totalTime,
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'WWW.JK-BMS.COM',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _sectionLabel('Hardware Overrides', colors),
            _panel(
              colors: colors,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: Icon(
                      Icons.electric_scooter,
                      color: scheme.primary,
                    ),
                    title: Text(
                      'Motor Power (Discharge)',
                      style: TextStyle(color: colors.primaryText),
                    ),
                    subtitle: Text(
                      battery.isDischarging
                          ? 'Enabled'
                          : 'Disabled (Immobilized)',
                      style: TextStyle(
                        color: battery.isDischarging
                            ? scheme.primary
                            : colors.secondaryText,
                      ),
                    ),
                    value: battery.isDischarging,
                    onChanged: batteryProvider.toggleDischarging,
                  ),
                  const Divider(height: 1, indent: 20, endIndent: 20),
                  SwitchListTile(
                    secondary: Icon(
                      Icons.power,
                      color: scheme.primary,
                    ),
                    title: Text(
                      'Charge Input',
                      style: TextStyle(color: colors.primaryText),
                    ),
                    subtitle: Text(
                      battery.isCharging
                          ? 'Accepting current'
                          : 'Cutoff active',
                      style: TextStyle(
                        color: battery.isCharging
                            ? scheme.primary
                            : colors.secondaryText,
                      ),
                    ),
                    value: battery.isCharging,
                    onChanged: batteryProvider.toggleCharging,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Center(
              child: TextButton.icon(
                onPressed: () {
                  _showSwitchScooterModal(context, batteryProvider);
                },
                icon: Icon(Icons.swap_horiz, color: scheme.primary),
                label: Text(
                  'Switch Scooter',
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}