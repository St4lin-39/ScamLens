import 'package:flutter/material.dart';
import 'package:scamlens/shared/ioc_verification/domain/entities/ioc_check_result.dart';
import 'package:scamlens/theme/app_theme.dart';

class IocThreatBanner extends StatelessWidget {
  final IocCheckResult? iocCheck;

  const IocThreatBanner({super.key, required this.iocCheck});

  @override
  Widget build(BuildContext context) {
    final result = iocCheck;
    if (result == null || !result.isConfirmedThreat || result.matchedIoc == null) {
      return const SizedBox.shrink();
    }

    final ioc = result.matchedIoc!;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.error, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.block_rounded, color: AppColors.error, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'CONFIRMED THREAT BLOCKED (IOC)',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  ioc.detectionSource,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${ioc.attackType} • ${ioc.type.dbCode}: ${ioc.value}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (result.heuristicDetail?.technicalEvidence case final evidence?) ...[
            const SizedBox(height: 4),
            Text(
              evidence,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
