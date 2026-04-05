import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';

/// Subtle amber banner shown when the device has no connectivity.
/// Design principle: Every screen works offline — this indicator is
/// informational only, never blocking.
class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final results = snapshot.data ?? [];
        final isOffline = results.isNotEmpty &&
            results.every((r) => r == ConnectivityResult.none);

        if (!isOffline) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          color: AppColors.offlineBanner,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: const Text(
            '${AppStrings.offline} | ${AppStrings.offlineRoman}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        );
      },
    );
  }
}
