import 'package:flutter/material.dart';
import '../../models/battery_data.dart';
import '../../widgets/battery_arc.dart';
import '../../widgets/info_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final batteryData = BatteryData.demo();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Image.asset('lib/assets/scooty.png', height: 300),
            BatteryArc(
              percentage: batteryData.soc / 100,
              range: batteryData.range.toInt(),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: const [
                InfoCard(
                  title: 'Distance Covered',
                  value: '2344',
                  unit: 'km',
                  icon: Icons.electric_bike,
                ),
                InfoCard(
                  title: 'CO2 Avoided',
                  value: '67.98',
                  unit: 'kg',
                  icon: Icons.eco,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
