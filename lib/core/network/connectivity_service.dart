import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus { online, offline }

class ConnectivityService extends StateNotifier<NetworkStatus> {
  final Connectivity _connectivity;

  ConnectivityService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity(),
        super(NetworkStatus.online) {
    _init();
  }

  void _init() {
    _connectivity.checkConnectivity().then(_updateStatus);
    _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final bool isConnected = results.any((ConnectivityResult r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);

    state = isConnected ? NetworkStatus.online : NetworkStatus.offline;
  }

  bool get isOnline => state == NetworkStatus.online;
  bool get isOffline => state == NetworkStatus.offline;

  Future<bool> isWifiOnly() async {
    final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }
}

final StateNotifierProvider<ConnectivityService, NetworkStatus> connectivityProvider =
    StateNotifierProvider<ConnectivityService, NetworkStatus>((Ref ref) {
  return ConnectivityService();
});
