
import 'package:flutter/material.dart';


class AddressRow extends StatelessWidget {
  const AddressRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String? address;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(icon, size: 12, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$label — ${address ?? '…'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
