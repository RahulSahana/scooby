import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

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

  // =======================================================
  // BLE SERVICE
  // =======================================================

  late final BleService bleService;

  // =======================================================
  // DEVICES
  // =======================================================

  List<BluetoothDevice> devices = [];

  // =======================================================
  // STATES
  // =======================================================

  bool isScanning = false;

  bool isConnecting = false;

  // =======================================================
  // INIT
  // =======================================================

  @override
  void initState() {

    super.initState();

    final batteryProvider =
    Provider.of<BatteryProvider>(
      context,
      listen: false,
    );

    bleService = BleService(
      batteryProvider: batteryProvider,
    );

    init();
  }

  // =======================================================
  // INITIALIZE
  // =======================================================

  Future<void> init() async {

    await requestPermissions();

    await startInitialScan();
  }

  // =======================================================
  // REQUEST PERMISSIONS
  // =======================================================

  Future<void> requestPermissions() async {

    await [

      Permission.bluetoothScan,

      Permission.bluetoothConnect,

      Permission.location,

    ].request();
  }

  // =======================================================
  // START SCAN
  // =======================================================

  Future<void> startInitialScan() async {

    if (isScanning) return;

    debugPrint("STARTING SCAN");

    setState(() {

      isScanning = true;
    });

    await bleService.startScan();

    await Future.delayed(
      const Duration(seconds: 5),
    );

    if (!mounted) return;

    debugPrint(
      "DEVICES FOUND: "
          "${bleService.devices.length}",
    );

    setState(() {

      devices = bleService.devices;

      isScanning = false;
    });
  }

  // =======================================================
  // CONNECT DEVICE
  // =======================================================

  Future<void> connectDevice(
      BluetoothDevice device,
      ) async {

    if (isConnecting) return;

    setState(() {

      isConnecting = true;
    });

    try {

      // Stop scan before connect
      await bleService.stopScan();

      // Connect
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

    } catch (e) {

      debugPrint(
        "CONNECT ERROR: $e",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(

        SnackBar(

          backgroundColor: Colors.red,

          content: Text(
            "Connection Failed: $e",
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

  // =======================================================
  // DISPOSE
  // =======================================================

  @override
  void dispose() {

    bleService.disconnect();

    super.dispose();
  }

  // =======================================================
  // UI
  // =======================================================

  @override
  Widget build(BuildContext context) {

    final batteryProvider =
    Provider.of<BatteryProvider>(
      context,
    );

    return Scaffold(

      backgroundColor: Colors.grey[50],

      appBar: AppBar(

        backgroundColor: Colors.transparent,

        elevation: 0,

        title: const Text(

          "Connect BMS",

          style: TextStyle(

            color: Colors.black,

            fontWeight: FontWeight.bold,

            fontSize: 24,
          ),
        ),

        actions: [

          // ===============================================
          // CONNECTION STATUS
          // ===============================================

          Padding(

            padding:
            const EdgeInsets.only(
              right: 16,
            ),

            child: Row(

              children: [

                Icon(

                  batteryProvider
                      .isConnected

                      ? Icons
                      .bluetooth_connected

                      : Icons
                      .bluetooth_disabled,

                  color:
                  batteryProvider
                      .isConnected

                      ? Colors.green

                      : Colors.red,
                ),

                const SizedBox(width: 8),

                Text(

                  batteryProvider
                      .isConnected

                      ? "Connected"

                      : "Disconnected",

                  style: TextStyle(

                    fontWeight:
                    FontWeight.bold,

                    color:
                    batteryProvider
                        .isConnected

                        ? Colors.green

                        : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      body: Column(

        crossAxisAlignment:
        CrossAxisAlignment.start,

        children: [

          // ===============================================
          // TITLE
          // ===============================================

          Padding(

            padding:
            const EdgeInsets.all(20),

            child: Text(

              "Nearby Devices",

              style: TextStyle(

                fontSize: 16,

                color: Colors.grey[600],

                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),

          // ===============================================
          // DEVICE LIST
          // ===============================================

          Expanded(

            child: devices.isEmpty &&
                !isScanning

                ? buildEmptyState()

                : ListView.builder(

              padding:
              const EdgeInsets
                  .symmetric(
                horizontal: 16,
              ),

              itemCount:
              devices.length,

              itemBuilder:
                  (context, index) {

                final device =
                devices[index];

                return buildDeviceCard(
                  device,
                );
              },
            ),
          ),
        ],
      ),

      // ===============================================
      // FLOATING ACTION BUTTON
      // ===============================================

      floatingActionButton:
      FloatingActionButton(

        backgroundColor:
        Colors.deepPurple,

        onPressed: startInitialScan,

        child: isScanning

            ? const Padding(

          padding:
          EdgeInsets.all(12),

          child:
          CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )

            : const Icon(
          Icons.refresh,
          color: Colors.white,
        ),
      ),
    );
  }

  // =======================================================
  // DEVICE CARD
  // =======================================================

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
        bottom: 12,
      ),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
        BorderRadius.circular(20),

        boxShadow: [

          BoxShadow(

            color:
            Colors.grey.withAlpha(20),

            spreadRadius: 2,

            blurRadius: 8,

            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: ListTile(

        contentPadding:
        const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 8,
        ),

        leading: CircleAvatar(

          backgroundColor:
          Colors.deepPurple
              .withAlpha(25),

          child: const Icon(
            Icons.electric_bike_outlined,
            color: Colors.deepPurple,
          ),
        ),

        title: Text(

          name,

          style: const TextStyle(

            fontWeight:
            FontWeight.bold,

            fontSize: 16,
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

            elevation: 0,

            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(
                12,
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
          ),
        ),
      ),
    );
  }

  // =======================================================
  // EMPTY STATE
  // =======================================================

  Widget buildEmptyState() {

    return Center(

      child: Column(

        mainAxisAlignment:
        MainAxisAlignment.center,

        children: [

          Icon(

            Icons.bluetooth_searching,

            size: 80,

            color: Colors.grey[300],
          ),

          const SizedBox(height: 16),

          Text(

            "No devices found",

            style: TextStyle(

              color: Colors.grey[500],

              fontSize: 18,
            ),
          ),

          const SizedBox(height: 8),

          TextButton(

            onPressed:
            startInitialScan,

            child: const Text(
              "Tap to refresh",
            ),
          ),
        ],
      ),
    );
  }
}