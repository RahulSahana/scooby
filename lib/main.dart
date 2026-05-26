import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/battery_provider.dart';

import 'screens/home/home_screen.dart';
import 'screens/charge/charge_screen.dart';
import 'screens/profile/profile_screen.dart';

void main() {

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

        scaffoldBackgroundColor:
        Colors.grey[50],
      ),

      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {

  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() =>
      _MyHomePageState();
}

class _MyHomePageState
    extends State<MyHomePage> {

  int selectedIndex = 0;

  // =======================================================
  // SCREENS
  // =======================================================

  final List<Widget> screens = [

    const HomeScreen(),

    const ChargeScreen(),

    const ProfileScreen(),
  ];

  // =======================================================
  // NAVIGATION
  // =======================================================

  void onItemTapped(int index) {

    setState(() {

      selectedIndex = index;
    });
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

            padding:
            const EdgeInsets.only(
              right: 16,
            ),

            child: Row(

              children: [

                Icon(

                  batteryProvider.isConnected

                      ? Icons.bluetooth_connected

                      : Icons.bluetooth_disabled,

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

                    color:
                    batteryProvider
                        .isConnected

                        ? Colors.green

                        : Colors.red,

                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      body: screens[selectedIndex],

      bottomNavigationBar:
      BottomNavigationBar(

        currentIndex: selectedIndex,

        selectedItemColor:
        Colors.deepPurple,

        onTap: onItemTapped,

        items:
        const <BottomNavigationBarItem>[

          BottomNavigationBarItem(

            icon: Icon(
              Icons.electric_bike_outlined,
            ),

            label: 'Home',
          ),

          BottomNavigationBarItem(

            icon: Icon(
              Icons.electric_bolt_outlined,
            ),

            label: 'Charge',
          ),

          BottomNavigationBarItem(

            icon: Icon(Icons.person),

            label: 'Profile',
          ),
        ],
      ),
    );
  }
}