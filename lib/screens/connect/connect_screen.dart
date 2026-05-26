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
  State<ConnectScreen> createState() =>
      _ConnectScreenState();
}

class _ConnectScreenState
    extends State<ConnectScreen> {

  // =========================================================
  // BLE SERVICE
  // =========================================================

  late final BleService bleService;

  // =========================================================
  // STATES
  // =========================================================

  bool isScanning = false;

  bool isConnecting = false;

  // =========================================================
  // DEVICES
  // =========================================================

  List<BluetoothDevice> devices = [];

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {

    super.initState();

    final batteryProvider =
    Provider.of<BatteryProvider>(
      context,
      listen: false,
    );

    bleService = batteryProvider.bleService;

    init();
  }

  // =========================================================
  // INITIALIZE
  // =========================================================

  Future<void> init() async {

    await requestPermissions();

    await startScan();
  }

  // =========================================================
  // PERMISSIONS
  // =========================================================

  Future<void> requestPermissions() async {

    await [

      Permission.bluetoothScan,

      Permission.bluetoothConnect,

      Permission.location,

    ].request();
  }

  // =========================================================
  // START SCAN
  // =========================================================

  Future<void> startScan() async {

    if (isScanning) return;

    setState(() {

      isScanning = true;
    });

    debugPrint("STARTING BLE SCAN");

    await bleService.startScan();

    await Future.delayed(
      const Duration(seconds: 5),
    );

    if (!mounted) return;

    setState(() {

      devices = bleService.devices;

      isScanning = false;
    });

    debugPrint(
      "DEVICES FOUND: "
          "${devices.length}",
    );
  }

  // =========================================================
  // CONNECT DEVICE
  // =========================================================

  Future<void> connectDevice(
      BluetoothDevice device,
      ) async {

    if (isConnecting) return;

    setState(() {

      isConnecting = true;
    });

    try {

      // Stop scan before connecting
      await bleService.stopScan();

      // Connect BLE device
      await bleService.connect(device);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(

        SnackBar(

          backgroundColor: Colors.green,

          content: Text(
            "Connected to "
                "${device.platformName}",
          ),
        ),
      );

      // =====================================================
      // OPEN DASHBOARD
      // =====================================================

      Navigator.pushReplacement(

        context,

        MaterialPageRoute(

          builder: (_) =>
          const MyHomePage(),
        ),
      );

    } catch (e) {

      debugPrint(
        "CONNECTION ERROR: $e",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(

        SnackBar(

          backgroundColor: Colors.red,

          content: Text(
            "Connection Failed",
          ),
        ),
      );

    } finally {

      if (mounted) {

        setState(() {

          isConnecting = false;
        });
      }
    }
  }

  // =========================================================
  // DISPOSE
  // =========================================================

  @override
  void dispose() {

    // Only stop scanning, don't disconnect!
    bleService.stopScan();

    super.dispose();
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
        cardColor: Colors.white,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            "Connect BMS",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          actions: [
            IconButton(
              onPressed: startScan,
              icon: isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.refresh,
                      color: Colors.deepPurple,
                    ),
            ),
          ],
        ),
        body: devices.isEmpty && !isScanning
            ? buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return buildDeviceCard(
                    device,
                  );
                },
              ),
      ),
    );
  }

  // =========================================================
  // DEVICE CARD
  // =========================================================

  Widget buildDeviceCard(
      BluetoothDevice device,
      ) {

    final name =
    device.platformName.isEmpty

        ? "Unknown Device"

        : device.platformName;

    return Container(

      margin:
      const EdgeInsets.only(
        bottom: 14,
      ),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
        BorderRadius.circular(22),

        boxShadow: [

          BoxShadow(

            color:
            Colors.grey.withAlpha(25),

            blurRadius: 10,

            offset:
            const Offset(0, 5),
          ),
        ],
      ),

      child: ListTile(

        contentPadding:
        const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),

        leading: CircleAvatar(

          radius: 28,

          backgroundColor:
          Colors.deepPurple
              .withAlpha(20),

          child: const Icon(

            Icons.bluetooth,

            color: Colors.deepPurple,

            size: 28,
          ),
        ),

        title: Text(

          name,

          style: const TextStyle(

            fontWeight:
            FontWeight.bold,

            fontSize: 18,
          ),
        ),

        subtitle: Text(

          device.remoteId.str,

          style: TextStyle(

            color: Colors.grey[500],

            fontSize: 12,
          ),
        ),

        trailing: ElevatedButton(

          style:
          ElevatedButton.styleFrom(

            backgroundColor:
            Colors.deepPurple,

            foregroundColor:
            Colors.white,

            padding:
            const EdgeInsets.symmetric(
              horizontal: 26,
              vertical: 14,
            ),

            shape:
            RoundedRectangleBorder(

              borderRadius:
              BorderRadius.circular(
                14,
              ),
            ),
          ),

          onPressed: isConnecting

              ? null

              : () => connectDevice(
            device,
          ),

          child: isConnecting

              ? const SizedBox(

            width: 18,
            height: 18,

            child:
            CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )

              : const Text(

            "Connect",

            style: TextStyle(
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // EMPTY STATE
  // =========================================================

  Widget buildEmptyState() {

    return Center(

      child: Column(

        mainAxisAlignment:
        MainAxisAlignment.center,

        children: [

          Icon(

            Icons.bluetooth_disabled,

            size: 90,

            color: Colors.grey[300],
          ),

          const SizedBox(height: 20),

          Text(

            "No BLE Devices Found",

            style: TextStyle(

              fontSize: 18,

              color: Colors.grey[600],

              fontWeight:
              FontWeight.w600,
            ),
          ),

          const SizedBox(height: 10),

          TextButton(

            onPressed: startScan,

            child: const Text(
              "Scan Again",
            ),
          ),
        ],
      ),
    );
  }
}