import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/sync/sync_provider.dart';
import '../../core/sync/sync_service.dart';

/// Subtle app-bar widget that communicates connectivity and sync state.
///
/// States:
/// - Online + idle (no pending):  hidden (SizedBox.shrink)
/// - Syncing:                     amber spinner + "مطابقت ہو رہی ہے..."
/// - Synced (briefly):            green dot + "مطابقت مکمل" for 3 s then fades
/// - Offline:                     grey wifi-off icon + "آف لائن"
/// - Error:                       orange warning icon + "مطابقت میں خرابی"
///
/// Uses [AnimatedSwitcher] for smooth crossfade between states.
class OfflineIndicator extends ConsumerStatefulWidget {
  const OfflineIndicator({super.key});

  @override
  ConsumerState<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends ConsumerState<OfflineIndicator> {
  // Whether to show the "synced" confirmation badge
  bool _showSynced = false;
  Timer? _syncedTimer;

  @override
  void dispose() {
    _syncedTimer?.cancel();
    super.dispose();
  }

  void _handleSyncStatus(SyncStatus? previous, SyncStatus next) {
    if (next == SyncStatus.synced) {
      setState(() => _showSynced = true);
      _syncedTimer?.cancel();
      _syncedTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showSynced = false);
      });
    } else if (next != SyncStatus.syncing) {
      _syncedTimer?.cancel();
      if (_showSynced) setState(() => _showSynced = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnlineAsync = ref.watch(isOnlineProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    // React to sync status transitions for the "synced" flash.
    ref.listen<SyncStatus>(syncStatusProvider, _handleSyncStatus);

    final isOnline = isOnlineAsync.valueOrNull ?? true;

    // Determine what to show
    _IndicatorData data;

    if (syncStatus == SyncStatus.syncing) {
      data = _IndicatorData.syncing();
    } else if (_showSynced && isOnline) {
      data = _IndicatorData.synced();
    } else if (!isOnline) {
      data = _IndicatorData.offline();
    } else if (syncStatus == SyncStatus.error) {
      data = _IndicatorData.error();
    } else {
      // Online + idle — hidden
      data = _IndicatorData.hidden();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: data.isHidden
          ? const SizedBox.shrink()
          : _IndicatorChip(key: ValueKey(data.key), data: data),
    );
  }
}

// ---------------------------------------------------------------------------
// _IndicatorData — simple value object describing what to render
// ---------------------------------------------------------------------------

class _IndicatorData {
  const _IndicatorData({
    required this.key,
    required this.label,
    required this.color,
    this.icon,
    this.showSpinner = false,
    this.isHidden = false,
  });

  factory _IndicatorData.syncing() => const _IndicatorData(
        key: 'syncing',
        label: AppStrings.syncing,
        color: Color(0xFFFF8F00), // amber[800]
        showSpinner: true,
      );

  factory _IndicatorData.synced() => const _IndicatorData(
        key: 'synced',
        label: AppStrings.synced,
        color: Color(0xFF2E7D32), // green
        icon: Icons.check_circle_outline,
      );

  factory _IndicatorData.offline() => const _IndicatorData(
        key: 'offline',
        label: AppStrings.offline,
        color: Color(0xFF9E9E9E), // muted grey per spec
        icon: Icons.wifi_off,
      );

  factory _IndicatorData.error() => const _IndicatorData(
        key: 'error',
        label: AppStrings.syncError,
        color: AppColors.accent, // orange
        icon: Icons.warning_amber_outlined,
      );

  factory _IndicatorData.hidden() => const _IndicatorData(
        key: 'hidden',
        label: '',
        color: Colors.transparent,
        isHidden: true,
      );

  final String key;
  final String label;
  final Color color;
  final IconData? icon;
  final bool showSpinner;
  final bool isHidden;
}

// ---------------------------------------------------------------------------
// _IndicatorChip — the actual rendered pill
// ---------------------------------------------------------------------------

class _IndicatorChip extends StatelessWidget {
  const _IndicatorChip({super.key, required this.data});

  final _IndicatorData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (data.showSpinner)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(data.color),
              ),
            )
          else if (data.icon != null)
            Icon(data.icon, size: 13, color: data.color),
          const SizedBox(width: 4),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 11,
              color: data.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
