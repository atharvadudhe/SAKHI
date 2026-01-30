import 'package:flutter/material.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

class QuickDialCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? phoneNumber;
  final VoidCallback onTap;

  const QuickDialCard({
    super.key,
    required this.icon,
    required this.label,
    this.phoneNumber,
    required this.onTap,
  });

  Future<void> _makeCall() async {
    if (phoneNumber != null) {
      try {
        await FlutterPhoneDirectCaller.callNumber(phoneNumber!);
      } catch (e) {
        // Handle error silently or show a message
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: phoneNumber != null ? _makeCall : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
