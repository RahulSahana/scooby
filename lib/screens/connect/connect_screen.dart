import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../../providers/battery_provider.dart';
import '../../widgets/app_update_banner.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen>
    with SingleTickerProviderStateMixin {
  // =========================================================
  // BLE SERVICE & STATES
  // =========================================================
  late BatteryProvider _batteryProvider;

  bool isScanning = false;
  bool isConnecting = false;
  bool _dashboardOpened = false;
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
    "Thanks For Using Scooby! 💝",
    "Happy Durga Puja",
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
    if (!await checkBluetoothSupport()) return;

    await _batteryProvider.garageReady;
    if (!mounted) return;

    // Web Bluetooth restriction: Scanning MUST be triggered by user interaction.
    // We skip automatic scanning/connecting on Web boot.
    if (kIsWeb) {
      setState(() => isConnecting = false);
      return;
    }

    if (_batteryProvider.isConnected ||
        _batteryProvider.isUsingRemoteTelemetry) {
      _onBatteryProviderChanged();
      return;
    }

    // A saved scooter is managed by BatteryProvider, which retries BLE and
    // polls its shared server telemetry. Avoid launching a second BLE scan here.
    if (_batteryProvider.primaryScooterId != null) {
      setState(() {
        isConnecting = _batteryProvider.isConnecting;
      });
      if (isConnecting) _startStatusTimer();
      if (_batteryProvider.isConnected ||
          _batteryProvider.isUsingRemoteTelemetry) {
        _onBatteryProviderChanged();
      }
      return;
    }

    await requestPermissions();
    if (!mounted) return;

    // Keep scanning locally while the provider checks the public server feed.
    setState(() => isConnecting = false);
    await startScan();
  }

  void _showConnectionScreen() {
    if (!mounted || !isConnecting) return;
    _stopStatusTimer();
    setState(() => isConnecting = false);
  }

  void _onBatteryProviderChanged() {
    if (!mounted) return;

    if (_batteryProvider.isConnected ||
        _batteryProvider.isUsingRemoteTelemetry) {
      if (_dashboardOpened) return;
      _dashboardOpened = true;
      debugPrint("OPENING DASHBOARD FOR SCOOBY TELEMETRY");
      _stopStatusTimer();
      unawaited(_batteryProvider.bleService.stopScan());

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyHomePage()),
      );
      return;
    }

    if (isConnecting && !_batteryProvider.isConnecting) {
      _showConnectionScreen();
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
        if (_statusIndex  == _statusMessages.length - 1) {
          _statusIndex=0;
        }
        if (_statusIndex  < _statusMessages.length - 1) {
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
    if (kIsWeb) return; // Web Bluetooth handled by browser chooser

    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<bool> checkBluetoothSupport() async {
    if (kIsWeb) {
      if (!await FlutterBluePlus.isSupported) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Bluetooth is not supported in this browser. "
                    "Please use Chrome or Edge.",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    }
    return true;
  }

  Future<void> startScan() async {
    if (isScanning) return;

    setState(() {
      isScanning = true;
      if (devices.isEmpty) _startStatusTimer();
    });

    await _batteryProvider.bleService.startScan();

    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;

    await _batteryProvider.bleService.stopScan();
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

    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        await _batteryProvider.bleService.stopScan();
        await _batteryProvider.bleService.connect(device);
        // _onBatteryProviderChanged handles the successful navigation.
        return;
      } catch (error) {
        debugPrint('BLE connection attempt $attempt/3 failed: $error');
        if (attempt < 3) {
          await Future<void>.delayed(Duration(seconds: attempt));
        }
      }
    }

    if (!mounted) return;
    _batteryProvider.setConnectingState(false);
    _stopStatusTimer();
    setState(() => isConnecting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(
          'Could not connect after 3 tries. Keep the BMS nearby and try again.',
        ),
      ),
    );
  }

  // =========================================================
  // UI LAYOUT
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          title: const Text(
            "Scooby ",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          actions: [
            if (!isConnecting)
              IconButton(
                onPressed: startScan,
                icon: isScanning
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.refresh, color: Colors.teal),
              ),
          ],
        ),
        body: Column(
          children: [
            const AppUpdateBanner(),
            Expanded(
              child: isConnecting || (isScanning && devices.isEmpty)
                  ? _buildCinematicConnectingView()
                  : (devices.isEmpty ? _buildEmptyState() : _buildDeviceList()),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // CINEMATIC RADAR VIEW
  // =========================================================
  Widget _buildCinematicConnectingView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final durgaSize =
            (availableHeight * 0.34).clamp(170.0, 280.0).toDouble();
        final radarSize =
            (availableHeight * 0.38).clamp(190.0, 300.0).toDouble();

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: availableHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'lib/assets/Durga.png',
                  width: durgaSize,
                  height: durgaSize,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: radarSize,
                  height: radarSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _radarController,
                        builder: (context, child) {
                          return CustomPaint(
                            size: Size(radarSize, radarSize),
                            painter: RadarPainter(
                              progress: _radarController.value,
                              color: Colors.teal,
                            ),
                          );
                        },
                      ),
                      Image.asset(
                        'lib/assets/scooty.png',
                        width: radarSize * 0.6,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
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
                      color: Colors.teal,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // MANUAL DEVICE LIST
  // =========================================================
  Widget _buildDeviceList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRemoteStatusCard(),
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Nearby Bluetooth devices',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        for (final device in devices) _buildDeviceCard(device),
        Center(
          child: TextButton.icon(
            onPressed: startScan,
            icon: const Icon(Icons.refresh),
            label: const Text('Scan for nearby scooter'),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(BluetoothDevice device) {
    final name =
    device.platformName.isEmpty ? "Unknown Device" : device.platformName;

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
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.deepPurple.withAlpha(20),
          child: const Icon(
            Icons.electric_bike_outlined,
            color: Colors.teal,
            size: 28,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Text(
          device.remoteId.str,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: () => connectDevice(device),
          child: const Text(
            "Connect",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildRemoteStatusCard(noNearbyScooter: true),
        Center(
          child: TextButton.icon(
            onPressed: startScan,
            icon: const Icon(Icons.refresh),
            label: const Text('Scan for nearby scooter'),
          ),
        ),
      ],
    );
  }

  Widget _buildRemoteStatusCard({bool noNearbyScooter = false}) {
    final isRemote = _batteryProvider.isUsingRemoteTelemetry;
    final feedState = _batteryProvider.remoteFeedState;
    final (feedTitle, feedMessage) = switch (feedState) {
      RemoteFeedState.checking => (
        noNearbyScooter
            ? 'No nearby scooter; checking server'
            : 'Checking Scooby server',
        'Scooby checks automatically for readings from the BMS-connected phone.',
      ),
      RemoteFeedState.waitingForPublisher => (
        'Waiting for the first battery reading',
        'The server is reachable, but no phone has uploaded telemetry yet. Connect a phone to the JK-BMS and keep Scooby open with internet access.',
      ),
      RemoteFeedState.live => (
        'Scooby server connected',
        'Live battery telemetry is arriving from the BMS-connected phone.',
      ),
      RemoteFeedState.stale => (
        'Server reading is out of date',
        'A reading exists, but it is older than 6 minutes. The BMS-connected phone needs to reconnect and upload a fresh reading.',
      ),
      RemoteFeedState.unavailable => (
        'Scooby server could not be reached',
        'Check the phone’s internet connection and the Vercel deployment, then Scooby will retry automatically.',
      ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRemote ? 'Scooby server connected' : feedTitle,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            feedMessage,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          if (feedState == RemoteFeedState.unavailable) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    unawaited(_batteryProvider.refreshRemoteTelemetry()),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Check again'),
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'This feed is public and includes battery telemetry and scooter location.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
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

  RadarPainter({
    required this.progress,
    required this.color,
  });

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
