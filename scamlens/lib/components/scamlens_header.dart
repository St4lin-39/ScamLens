import 'package:flutter/material.dart';
import 'package:scamlens/theme/app_theme.dart';

class ScamLensHeader extends StatelessWidget {
  final bool showProtectedBadge;

  const ScamLensHeader({super.key, this.showProtectedBadge = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accentCyan.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.accentCyan.withValues(alpha: 0.4),
            ),
          ),
          child: const Icon(
            Icons.travel_explore_rounded,
            color: AppColors.accentCyan,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ScamLens',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'v1.1 • Escudo anti-phishing',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (showProtectedBadge)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.safeGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.safeGreen.withValues(alpha: 0.5),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: AppColors.safeGreen),
                SizedBox(width: 6),
                Text(
                  'PROTEGIDO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.safeGreen,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
