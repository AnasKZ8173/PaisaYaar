import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityService {
  const ConnectivityService._();

  static Future<bool> hasInternet() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }
}

final internetStatusProvider = StreamProvider<bool>((ref) async* {
  yield await ConnectivityService.hasInternet();
  await for (final results in Connectivity().onConnectivityChanged) {
    yield results.any((r) => r != ConnectivityResult.none);
  }
});
