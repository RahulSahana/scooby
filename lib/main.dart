import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:scooby/providers/navigation_provider.dart';
import 'package:scooby/screens/connect/connect_screen.dart';
import 'package:scooby/services/notification_service.dart';

import 'providers/battery_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_colors.dart';

import 'screens/home/home_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'widgets/connection_badge.dart';
import 'screens/navigate/navigate_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();

  // IMMERSIVE PREMIUM UI CONFIGURATION
  // SystemChrome.setSystemUIOverlayStyle(
  //   const SystemUiOverlayStyle(
  //     statusBarColor: Colors.transparent, // Makes the bar itself transparent
  //     statusBarIconBrightness: Brightness.dark, // Dark icons for Android (clock, wifi, battery)
  //     statusBarBrightness: Brightness.light, // Dark icons for iOS
  //     systemNavigationBarColor: Colors.transparent, // Optional: applies to the bottom nav bar too
  //     systemNavigationBarIconBrightness: Brightness.dark,
  //   ),
  // );

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BatteryProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(
          create: (_) => NavigationProvider(),
        ),
      ],
      child: const Scooby(),
    ),
  );
}

ThemeData _buildTheme(AppColors colors, Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: colors.primary,
    brightness: brightness,
  ).copyWith(
    primary: colors.primary,
    secondary: colors.secondary,
    error: colors.criticalRed,
    surface: colors.cardColor,
    onSurface: colors.primaryText,
    outline: colors.cardBorder,
  );

  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: colors.background,
    colorScheme: colorScheme,
    useMaterial3: true,
    extensions: <ThemeExtension<dynamic>>[colors],
  );
}

class Scooby extends StatelessWidget {
  const Scooby({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'Scooby',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(AppColors.light, Brightness.light),
      darkTheme: _buildTheme(AppColors.dark, Brightness.dark),
      themeMode: themeProvider.themeMode,
      home: const AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        //child: ConnectScreen(),
        //child: NavigateScreen(),
        //child: HomeScreen(),
        child: ProfileScreen(),
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
  late PageController _pageController;
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const NavigateScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 100),
      curve: Curves.bounceOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Status Bar Brightness based on screen (Charge/Profile are Dark)
    final isDarkScreen = _selectedIndex == 1 || _selectedIndex == 2;

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
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          titleSpacing: 16,
          title: const Text(
            'Scooby',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          flexibleSpace: IgnorePointer(
            child: SafeArea(
              child: Center(
                child: Image.asset(
                  'lib/assets/eyes.png',
                  width: 60,
                  fit: BoxFit.fitHeight,
                ),
              ),
            ),
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: ConnectionBadge(isSmall: true),
            ),
          ],
        ),
        body: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: const BouncingScrollPhysics(),
          children: _screens,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.teal,
          onTap: _onItemTapped,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.electric_bike_outlined),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on_outlined),
              label: 'Navigate',
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
