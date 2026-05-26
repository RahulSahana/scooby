import 'package:flutter/material.dart';

class ChargeScreen extends StatelessWidget {
  const ChargeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.electric_bolt_outlined, size: 100, color: Colors.deepPurple),
          Text('Charge Screen', style: TextStyle(fontSize: 24)),
        ],
      ),
    );
  }
}
