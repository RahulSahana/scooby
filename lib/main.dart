import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/battery_provider.dart';

import 'screens/home/home_screen.dart';
import 'screens/charge/charge_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/connect/connect_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // IMMERSIVE PREMIUM UI CONFIGURATION
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => BatteryProvider(),
      child: const Scooby(),
    ),
  );
}

class Scooby extends StatelessWidget {
  const Scooby({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Scooby',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
        ),
        useMaterial3: true,
      ),
      home: const AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: ConnectScreen(),
        //child: ChargeScreen(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int selectedIndex = 0;

  final List<Widget> screens = [
    const HomeScreen(),
    const ChargeScreen(),
    const ProfileScreen(),
  ];

  void onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final batteryProvider = Provider.of<BatteryProvider>(context);

    // Dynamic Status Bar Brightness based on screen (Charge/Profile are Dark)
    final isDarkScreen = selectedIndex == 1 || selectedIndex == 2;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDarkScreen ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDarkScreen ? Brightness.dark : Brightness.light,
        systemNavigationBarIconBrightness: isDarkScreen ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            "Scooby",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Icon(
                    batteryProvider.isConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth_disabled,
                    color: batteryProvider.isConnected ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    batteryProvider.isConnected ? "Connected" : "Disconnected",
                    style: TextStyle(
                      color: batteryProvider.isConnected ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        body: screens[selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: selectedIndex,
          selectedItemColor: Colors.deepPurple,
          onTap: onItemTapped,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.electric_bike_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.electric_bolt_outlined),
              label: 'Charge',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
