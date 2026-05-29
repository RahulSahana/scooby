import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/battery_provider.dart';

class ConnectionBadge extends StatelessWidget {
  final bool isSmall;

  const ConnectionBadge({super.key, this.isSmall = false});

  @override
  Widget build(BuildContext context) {
    final batteryProvider = context.watch<BatteryProvider>();
    final isConnected = batteryProvider.isConnected;
    final isConnecting = batteryProvider.isConnecting;

    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (isConnecting) {
      badgeColor = Colors.orange;
      badgeText = isSmall ? '...' : 'Connecting...';
      badgeIcon = Icons.bluetooth_searching;
    } else if (isConnected) {
      badgeColor = Colors.green;
      badgeText = isSmall ? '' : 'Connected';
      badgeIcon = Icons.bluetooth_connected;
    } else {
      badgeColor = Colors.redAccent;
      badgeText = isSmall ? '' : 'Disconnected';
      badgeIcon = Icons.bluetooth_disabled;
    }

    return GestureDetector(
      onTap: () {
        if (!isConnected && !isConnecting) {
          batteryProvider.forceManualReconnect();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 8 : 12,
          vertical: isSmall ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isConnecting)
              SizedBox(
                width: isSmall ? 12 : 14,
                height: isSmall ? 12 : 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: badgeColor,
                ),
              )
            else
              Icon(badgeIcon, color: badgeColor, size: isSmall ? 14 : 16),
            if (badgeText.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                badgeText,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: isSmall ? 10 : 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
