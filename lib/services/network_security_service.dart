import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// DNS/VPN ve reklam engelleyici tespiti.
class NetworkSecurityService {
  NetworkSecurityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Aktif VPN tüneli veya özel DNS (reklam engelleyici) tespit edildi mi?
  Future<bool> hasUnsafeConnection() async {
    if (kIsWeb) return false;

    final vpnDetected = await _detectVpn();
    if (vpnDetected) return true;

    final dnsBlocked = await _detectAdBlockerDns();
    return dnsBlocked;
  }

  Future<bool> _detectVpn() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.contains(ConnectivityResult.vpn);
    } catch (_) {
      return false;
    }
  }

  /// Bilinen reklam sunucusuna DNS çözümlemesi başarısızsa
  /// muhtemelen özel DNS / reklam engelleyici aktiftir.
  Future<bool> _detectAdBlockerDns() async {
    if (kIsWeb) return false;

    const probeHosts = [
      'pagead2.googlesyndication.com',
      'googleads.g.doubleclick.net',
    ];

    for (final host in probeHosts) {
      try {
        final result = await InternetAddress.lookup(host)
            .timeout(const Duration(milliseconds: 800));
        if (result.isEmpty || result.first.rawAddress.isEmpty) {
          return true;
        }
      } on SocketException {
        return true;
      } on TimeoutException {
        return true;
      } catch (_) {
        // Diğer hatalarda güvenli tarafta kal — engelleme yok sayılır.
      }
    }
    return false;
  }
}
