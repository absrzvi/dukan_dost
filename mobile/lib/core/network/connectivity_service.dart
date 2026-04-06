import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitors device connectivity and exposes a stream for offline-aware UI.
/// Iron Rule: Every screen works offline. A loading spinner on transaction
/// entry is an architecture failure.
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Stream of connectivity results. Widgets listen to this to show
  /// the offline banner or adjust sync behavior.
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;

  /// Convenience stream of bool — true when at least one non-none result.
  /// Bluetooth connections are excluded (they don't provide internet access).
  Stream<bool> get isOnlineStream => _connectivity.onConnectivityChanged.map(
        (results) => results.any(
          (r) =>
              r != ConnectivityResult.none &&
              r != ConnectivityResult.bluetooth,
        ),
      );

  /// Check current connectivity status.
  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any(
      (r) =>
          r != ConnectivityResult.none && r != ConnectivityResult.bluetooth,
    );
  }
}
