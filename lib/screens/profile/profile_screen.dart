import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/battery_provider.dart';
import '../connect/connect_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _passwordController;

  String _userName = "Rahul Sahana";
  String _userDesc = "West Bengal • App Developer";
  String _userAvatar = "🤖";

  final List<String> _avatarOptions = ["🤖", "👽", "🦊", "🐶", "🚀", "⚡", "👾", "🏍️"];

  @override
  void initState() {
    super.initState();
    final currentPassword = context.read<BatteryProvider>().bmsPassword;
    _passwordController = TextEditingController(text: currentPassword);
    _loadProfileData();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('profile_name') ?? "Rahul Sahana";
      _userDesc = prefs.getString('profile_desc') ?? "West Bengal • EV Developer";
      _userAvatar = prefs.getString('profile_avatar') ?? "🤖";
    });
  }

  Future<void> _saveProfileData(String name, String desc, String avatar) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name', name);
    await prefs.setString('profile_desc', desc);
    await prefs.setString('profile_avatar', avatar);

    setState(() {
      _userName = name;
      _userDesc = desc;
      _userAvatar = avatar;
    });
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _userName);
    final descController = TextEditingController(text: _userDesc);
    String selectedAvatar = _userAvatar;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: Colors.white,
              title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Choose an Avatar', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _avatarOptions.map((avatar) {
                        final isSelected = avatar == selectedAvatar;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedAvatar = avatar),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF8B5CF6).withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
                                width: 2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Text(avatar, style: const TextStyle(fontSize: 28)),
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
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descController,
                      decoration: InputDecoration(
                        labelText: 'Tagline',
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    _saveProfileData(nameController.text, descController.text, selectedAvatar);
                    Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSwitchScooterModal(BuildContext context, BatteryProvider provider) {
    provider.bleService.disconnect();
    provider.bleService.startScan();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future.delayed(const Duration(seconds: 1), () {
              if (mounted) setModalState(() {});
            });

            final devices = provider.bleService.devices;

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Nearby Scooters", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    devices.isEmpty ? "Scanning Space..." : "Select secondary vehicle to override connection.",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  if (devices.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        final name = device.platformName.isEmpty ? "Unknown Scooty" : device.platformName;

                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE2D4F8),
                            child: Icon(Icons.electric_bike, color: Color(0xFF8B5CF6), size: 20),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(device.remoteId.str, style: const TextStyle(fontSize: 12)),
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
            );
          },
        );
      },
    ).whenComplete(() => provider.bleService.stopScan());
  }

  @override
  Widget build(BuildContext context) {
    final batteryProvider = context.watch<BatteryProvider>();
    final battery = batteryProvider.batteryData;

    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF9F9F9),
        primaryColor: const Color(0xFF8B5CF6),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9F9),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(color: Color(0xFFE2D4F8), shape: BoxShape.circle),
                            child: Text(_userAvatar, style: const TextStyle(fontSize: 32)),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(height: 4),
                              Text(_userDesc, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Color(0xFF8B5CF6)),
                        onPressed: _showEditProfileDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // ==========================================
                  // MY GARAGE DESIGNATED MANAGEMENT
                  // ==========================================
                  const Text('MY GARAGE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Primary Scooter', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('The app will prioritize auto-connecting to this address on launch.', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: batteryProvider.primaryScooterId,
                              hint: const Text("No Vehicles Saved"),
                              icon: const Icon(Icons.electric_bike, color: Color(0xFF8B5CF6)),
                              items: batteryProvider.savedGarage.map((scooter) {
                                return DropdownMenuItem<String>(
                                  value: scooter['id'],
                                  child: Text(scooter['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                                );
                              }).toList(),
                              onChanged: (String? newId) {
                                if (newId != null) batteryProvider.setPrimaryScooter(newId);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ==========================================
                  // BMS SECURITY CONFIGURATION
                  // ==========================================
                  const Text('BMS SECURITY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Device Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Required to send hardware state command structures.', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _passwordController,
                                decoration: InputDecoration(
                                  hintText: 'e.g., 1234 or 802626052E',
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () {
                                batteryProvider.setBmsPassword(_passwordController.text);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Password updated!'), backgroundColor: Colors.green),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ==========================================
                  // HARDWARE OVERRIDES
                  // ==========================================
                  const Text('HARDWARE OVERRIDES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.grey)),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.08), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.electric_scooter, color: Colors.blue),
                          ),
                          title: const Text('Motor Power (Discharge)', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(battery.isDischarging ? 'Enabled' : 'Disabled (Immobilized)', style: TextStyle(color: battery.isDischarging ? Colors.green : Colors.red)),
                          trailing: Switch(
                            value: battery.isDischarging,
                            activeColor: Colors.blue,
                            onChanged: (val) => batteryProvider.toggleDischarging(val),
                          ),
                        ),
                        const Divider(height: 1, indent: 20, endIndent: 20),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.power, color: Colors.green),
                          ),
                          title: const Text('Charge Input', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(battery.isCharging ? 'Accepting Current' : 'Cutoff Active', style: TextStyle(color: battery.isCharging ? Colors.green : Colors.orange)),
                          trailing: Switch(
                            value: battery.isCharging,
                            activeColor: Colors.green,
                            onChanged: (val) => batteryProvider.toggleCharging(val),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ==========================================
                  // HOT SWAP TRIGGER
                  // ==========================================
                  Center(
                    child: TextButton.icon(
                      onPressed: () => _showSwitchScooterModal(context, batteryProvider),
                      icon: const Icon(Icons.swap_horiz, color: Color(0xFF8B5CF6)),
                      label: const Text('Switch Scooter', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}