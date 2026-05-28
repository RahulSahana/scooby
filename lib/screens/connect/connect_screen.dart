import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../providers/battery_provider.dart';
import '../../services/ble_service.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

// Added SingleTickerProviderStateMixin for the radar animation
class _ConnectScreenState extends State<ConnectScreen> with SingleTickerProviderStateMixin {

  // =========================================================
  // BLE SERVICE & STATES
  // =========================================================
  late final BleService bleService;
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
  // INIT
  // =========================================================
  @override
  void initState() {
    super.initState();

    final batteryProvider = Provider.of<BatteryProvider>(context, listen: false);
    bleService = batteryProvider.bleService;
    batteryProvider.addListener(_onBatteryProviderChanged);

    // Setup Radar Animation
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // Loops continuously

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await requestPermissions();

    if (!mounted) return;

    // Start the cinematic connection sequence
    setState(() => isConnecting = true);
    _startStatusTimer();

    final autoConnectSuccess = await bleService.autoConnect();

    if (autoConnectSuccess) {
      return;
    } else {
      if (mounted) {
        _stopStatusTimer();
        setState(() => isConnecting = false);
        await startScan();
      }
    }
  }

  // =========================================================
  // STATUS TIMER LOGIC
  // =========================================================
  void _startStatusTimer() {
    _statusIndex = 0;
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

  void _onBatteryProviderChanged() {
    final batteryProvider = Provider.of<BatteryProvider>(context, listen: false);
    if (batteryProvider.isConnected && mounted) {
      debugPrint("AUTO-NAVIGATING TO DASHBOARD");
      bleService.stopScan();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyHomePage()),
      );
    }
  }

  @override
  void dispose() {
    Provider.of<BatteryProvider>(context, listen: false)
        .removeListener(_onBatteryProviderChanged);

    _radarController.dispose();
    _stopStatusTimer();
    bleService.stopScan();
    super.dispose();
  }

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
      if (devices.isEmpty) _startStatusTimer(); // Start text animation if screen is empty
    });

    debugPrint("STARTING BLE SCAN");
    await bleService.startScan();

    await Future.delayed(const Duration(seconds: 5));

    if (!mounted) return;
    
    _stopStatusTimer(); // Stop the text animation when done
    setState(() {
      devices = bleService.devices;
      isScanning = false;
    });
    debugPrint("DEVICES FOUND: ${devices.length}");
  }

  Future<void> connectDevice(BluetoothDevice device) async {
    if (isConnecting) return;

    // If they manually connect, trigger the radar view again
    setState(() {
      isConnecting = true;
      _startStatusTimer();
    });

    try {
      await bleService.stopScan();
      await bleService.connect(device);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.green, content: Text("Connected to ${device.platformName}")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyHomePage()),
      );
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
  // UI
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
          title: const Text(
            "Scooby ",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          actions: [
            if (!isConnecting) // Hide refresh when radar is active
              IconButton(
                onPressed: startScan,
                icon: isScanning
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, color: Colors.deepPurple),
              ),
          ],
        ),
        // Switch between the cinematic view and the manual list
        body: isConnecting || (isScanning && devices.isEmpty)
            ? _buildCinematicConnectingView()
            : (devices.isEmpty ? _buildEmptyState() : _buildDeviceList()),
      ),
    );
  }

  // =========================================================
  // THE NEW CINEMATIC RADAR VIEW
  // =========================================================
  Widget _buildCinematicConnectingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // RADAR ANIMATION STACK
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
                // The scooter image sitting in the center
                Image.asset(
                  'lib/assets/scooty.png',
                  width: 180,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),

          // PROGRESSIVE STATUS TEXT
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
              key: ValueKey<int>(_statusIndex), // Forces AnimatedSwitcher to trigger
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
        boxShadow: [BoxShadow(color: Colors.grey.withAlpha(25), blurRadius: 10, offset: const Offset(0, 5))],
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

    // Draw 3 distinct ripples
    for (int i = 0; i < 3; i++) {
      // Offset each ripple's progress so they follow each other
      final rippleProgress = (progress + (i * 0.33)) % 1.0;
      final radius = maxRadius * rippleProgress;

      // Fade out as it expands
      final opacity = (1.0 - rippleProgress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.4) // Base opacity dialed down for a softer glow
        ..style = PaintingStyle.fill;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}