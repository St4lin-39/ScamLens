import 'package:flutter/material.dart';
import 'package:scamlens/shared/brand_impersonation/domain/entities/brand_impersonation_result.dart';
import 'package:scamlens/theme/app_theme.dart';

class BrandImpersonationBanner extends StatelessWidget {
  final BrandImpersonationResult? impersonation;

  const BrandImpersonationBanner({super.key, required this.impersonation});

  @override
  Widget build(BuildContext context) {
    final result = impersonation;
    if (result == null) return const SizedBox.shrink();

    if (result.isSuspectedImpersonation && result.matchedBrand != null) {
      final brand = result.matchedBrand!;
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.error),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.gpp_bad_rounded, color: AppColors.error, size: 18),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'POSSIBLE BRAND IMPERSONATION',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Resembles ${brand.entityName} (${brand.officialDomain})',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (result.heuristicDetail?.technicalEvidence
                case final evidence?) ...[
              const SizedBox(height: 4),
              Text(
                evidence,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (result.isOfficialVerified && result.matchedBrand != null) {
      final brand = result.matchedBrand!;
      return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.safeGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.safeGreen),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.verified_user_rounded,
              color: AppColors.safeGreen,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Verified official domain: ${brand.entityName} (${brand.officialDomain})',
                style: const TextStyle(
                  color: AppColors.safeGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
