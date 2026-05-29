import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../providers/battery_provider.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> with SingleTickerProviderStateMixin {
  // =========================================================
  // BLE SERVICE & STATES
  // =========================================================
  late BatteryProvider _batteryProvider;

  bool isScanning = false;
  bool isConnecting = false;
  List<BluetoothDevice> devices = [];

  // =========================================================
  // ANIMATION & STATUS TEXT STATES
  // =========================================================
  late AnimationController _radarController;
  Timer? _statusTimer;
  int _statusIndex = 0;

  final List<String> _statusMessages = [
    "Waking up BMS...",
    "Scanning for vehicle...",
    "Establishing secure link...",
    "Syncing telemetry...",
  ];

  // =========================================================
  // INIT & DISPOSE
  // =========================================================
  @override
  void initState() {
    super.initState();

    // 1. Save the provider to a variable when the screen first loads
    _batteryProvider = context.read<BatteryProvider>();
    _batteryProvider.addListener(_onBatteryProviderChanged);

    // Setup Radar Animation
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // Loops continuously

    _initializeApp();
  }

  @override
  void dispose() {
    // 2. Safely remove the listener using the saved variable
    _batteryProvider.removeListener(_onBatteryProviderChanged);

    _radarController.dispose();
    _stopStatusTimer();
    _batteryProvider.bleService.stopScan();

    super.dispose();
  }

  // =========================================================
  // APP LOGIC
  // =========================================================
  Future<void> _initializeApp() async {
    await requestPermissions();
    if (!mounted) return;

    // Start the cinematic connection sequence
    setState(() => isConnecting = true);
    _startStatusTimer();

    // Attempt auto-connect
    final autoConnectSuccess = await _batteryProvider.bleService.autoConnect(license: License.free);

    if (!autoConnectSuccess && mounted) {
      _stopStatusTimer();
      setState(() => isConnecting = false);
      await startScan();
    }
  }

  void _onBatteryProviderChanged() {
    if (!mounted) return; // THIS LINE STOPS THE CRASHES!

    if (_batteryProvider.isConnected) {
      debugPrint("AUTO-NAVIGATING TO DASHBOARD");
      _stopStatusTimer();
      _batteryProvider.bleService.stopScan();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyHomePage()),
      );
    }
  }

  // =========================================================
  // STATUS TIMER LOGIC
  // =========================================================
  void _startStatusTimer() {
    _statusIndex = 0;
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {
        if (_statusIndex < _statusMessages.length - 1) {
          _statusIndex++;
        }
      });
    });
  }

  void _stopStatusTimer() {
    _statusTimer?.cancel();
  }

  // =========================================================
  // HARDWARE PIPELINE
  // =========================================================
  Future<void> requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> startScan() async {
    if (isScanning) return;

    setState(() {
      isScanning = true;
      if (devices.isEmpty) _startStatusTimer();
    });

    debugPrint("STARTING BLE SCAN");
    await _batteryProvider.bleService.startScan();

    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;

    _stopStatusTimer();
    setState(() {
      devices = _batteryProvider.bleService.devices;
      isScanning = false;
    });
    debugPrint("DEVICES FOUND: ${devices.length}");
  }

  Future<void> connectDevice(BluetoothDevice device) async {
    if (isConnecting) return;

    setState(() {
      isConnecting = true;
      _startStatusTimer();
    });

    try {
      await _batteryProvider.bleService.stopScan();
      await _batteryProvider.bleService.connect(device);
      // NOTE: We don't call Navigator.push() here anymore!
      // _onBatteryProviderChanged will automatically detect the success and push the screen for us.
    } catch (e) {
      if (!mounted) return;
      _stopStatusTimer();
      setState(() => isConnecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(backgroundColor: Colors.red, content: Text("Connection Failed")),
      );
    }
  }

  // =========================================================
  // UI LAYOUT
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
      ),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          title: const Text(
            "Scooby ",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          actions: [
            if (!isConnecting)
              IconButton(
                onPressed: startScan,
                icon: isScanning
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, color: Colors.deepPurple),
              ),
          ],
        ),
        body: isConnecting || (isScanning && devices.isEmpty)
            ? _buildCinematicConnectingView()
            : (devices.isEmpty ? _buildEmptyState() : _buildDeviceList()),
      ),
    );
  }

  // =========================================================
  // CINEMATIC RADAR VIEW
  // =========================================================
  Widget _buildCinematicConnectingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 300,
            height: 300,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _radarController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(300, 300),
                      painter: RadarPainter(
                        progress: _radarController.value,
                        color: Colors.deepPurple,
                      ),
                    );
                  },
                ),
                Image.asset(
                  'lib/assets/scooty.png',
                  width: 180,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Text(
              _statusMessages[_statusIndex],
              key: ValueKey<int>(_statusIndex),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.deepPurple,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MANUAL DEVICE LIST
  // =========================================================
  Widget _buildDeviceList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: devices.length,
      itemBuilder: (context, index) => _buildDeviceCard(devices[index]),
    );
  }

  Widget _buildDeviceCard(BluetoothDevice device) {
    final name = device.platformName.isEmpty ? "Unknown Device" : device.platformName;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(25),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.deepPurple.withAlpha(20),
          child: const Icon(Icons.electric_bike_outlined, color: Colors.deepPurple, size: 28),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(device.remoteId.str, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () => connectDevice(device),
          child: const Text("Connect", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_disabled, size: 90, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text("No BLE Devices Found", style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextButton(onPressed: startScan, child: const Text("Scan Again")),
        ],
      ),
    );
  }
}

// =========================================================
// RADAR CUSTOM PAINTER
// =========================================================
class RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  RadarPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final rippleProgress = (progress + (i * 0.33)) % 1.0;
      final radius = maxRadius * rippleProgress;
      final opacity = (1.0 - rippleProgress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.4)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}