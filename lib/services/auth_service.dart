import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'daily_mini_exam_service.dart';
import '../models/user_model.dart';
import 'ad_manager.dart';
import 'app_preferences.dart';
import 'database_service.dart';
import 'play_billing_service.dart';
import 'premium_service.dart';
import 'question_rating_service.dart';

/// Firebase anonim oturum + isteğe bağlı Google hesabı bağlama.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _kToken = 'auth_api_token';
  static const _kUser = 'auth_user_json';
  static const _kLocalGuestId = 'local_guest_id';
  static const _localTokenPrefix = 'local:';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId:
        '89822639053-hj0d3dqf5291nepb5evoj6oc8phv5l26.apps.googleusercontent.com',
  );

  UserModel? _user;
  String? _token;
  bool _ready = false;
  bool _busy = false;
  String? _lastError;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isSignedIn => _user != null && (_token?.isNotEmpty ?? false);
  bool get isAnonymous => _user?.isAnonymous ?? false;
  bool get isLocalGuest => (_token ?? '').startsWith(_localTokenPrefix);
  bool get hasBackendSession => isSignedIn && !isLocalGuest;
  bool get hasPermanentAccount => hasBackendSession && !isAnonymous;
  bool get ready => _ready;
  bool get busy => _busy;
  String? get lastError => _lastError;

  Map<String, String> get authHeaders {
    final t = _token;
    if (t == null || t.isEmpty) return {'Accept': 'application/json'};
    return {
      'Accept': 'application/json',
      'Authorization': 'Bearer $t',
    };
  }

  Future<void> initialize() async {
    if (_ready) return;
    final prefs = await AppPreferences.instance;
    _token = prefs.getString(_kToken);
    final raw = prefs.getString(_kUser);
    if (raw != null && raw.isNotEmpty) {
      try {
        _user = UserModel.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {
        _user = null;
        _token = null;
      }
    }

    if (!isSignedIn) {
      _seedLocalGuestSession(prefs);
      unawaited(_persist());
    }

    _ready = true;
    notifyListeners();

    if (_user != null) {
      _syncPremiumSideEffects();
    }
    if (hasBackendSession) {
      refreshProfile().then((_) {}, onError: (_) {});
    }
    if (!hasBackendSession) {
      unawaited(ensureAnonymousSession());
    }
  }

  void _seedLocalGuestSession(SharedPreferences prefs) {
    var guestId = prefs.getString(_kLocalGuestId);
    guestId ??= 'guest-${DateTime.now().millisecondsSinceEpoch}';
    unawaited(prefs.setString(_kLocalGuestId, guestId));

    _token = '$_localTokenPrefix$guestId';
    _user = UserModel(
      id: guestId,
      isim: 'Misafir',
      eposta: '',
      isAnonymous: true,
    );
    _lastError = null;
    _syncPremiumSideEffects();
  }

  Future<bool> _activateLocalGuestSession({String? hint}) async {
    final prefs = await AppPreferences.instance;
    _seedLocalGuestSession(prefs);
    _lastError = hint;
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> _ensureFirebaseReady() async {
    if (Firebase.apps.isNotEmpty) return;
    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('Firebase init: $e');
    }
  }

  /// Sunucu + Firebase anonim oturumu; olmazsa yerel misafir modu.
  Future<bool> ensureAnonymousSession() async {
    if (_busy) return isSignedIn;
    if (hasBackendSession) return true;

    _busy = true;
    final previousError = _lastError;
    _lastError = null;
    notifyListeners();
    try {
      await _ensureFirebaseReady();
      User? fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null && !fbUser.isAnonymous) {
        final idToken = await fbUser.getIdToken();
        if (idToken != null &&
            idToken.isNotEmpty &&
            await _exchangeWithBackend(idToken: idToken)) {
          return true;
        }
      }

      fbUser ??= (await FirebaseAuth.instance.signInAnonymously()).user;
      if (fbUser == null) {
        return _activateLocalGuestSession(
          hint: previousError ?? 'Anonim oturum başlatılamadı.',
        );
      }

      final idToken = await fbUser.getIdToken();
      if (idToken == null || idToken.isEmpty) {
        return _activateLocalGuestSession(
          hint: 'Kimlik jetonu alınamadı.',
        );
      }

      if (await _exchangeWithBackend(idToken: idToken)) {
        return true;
      }

      return _activateLocalGuestSession(
        hint: _lastError ??
            'Sunucuya ulaşılamadı. Çevrimdışı misafir modundasın.',
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Anonim giriş: $e');
      final hint = e.code == 'admin-restricted-operation'
          ? 'Firebase anonim giriş kapalı. Çevrimdışı misafir modundasın.'
          : 'Uygulama oturumu başlatılamadı.';
      return _activateLocalGuestSession(hint: hint);
    } catch (e) {
      debugPrint('Anonim giriş: $e');
      return _activateLocalGuestSession(
        hint: 'Uygulama oturumu başlatılamadı.',
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> applyUserFromBackend(UserModel user) async {
    _user = user;
    await _persist();
    _syncPremiumSideEffects();
    notifyListeners();
  }

  Future<bool> refreshProfile() async {
    if (isLocalGuest) return false;
    final t = _token;
    if (t == null || t.isEmpty) return false;
    try {
      final res = await http
          .get(ApiConfig.meUri(), headers: authHeaders)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 401) {
        await _clearLocal();
        notifyListeners();
        return false;
      }
      if (res.statusCode != 200) return false;
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      if (json is! Map) return false;
      _user = UserModel.fromJson(Map<String, dynamic>.from(json));
      await _persist();
      _syncPremiumSideEffects();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Profil yenileme: $e');
      return false;
    }
  }

  Future<bool> updateDisplayName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      _lastError = 'Ad boş olamaz.';
      notifyListeners();
      return false;
    }
    if (isAnonymous) {
      _lastError = 'Ad kaydetmek için Google ile giriş yapın.';
      notifyListeners();
      return false;
    }
    if (_token == null || _token!.isEmpty) {
      _lastError = 'Oturum gerekli.';
      notifyListeners();
      return false;
    }
    _busy = true;
    _lastError = null;
    try {
      final res = await http
          .patch(
            ApiConfig.meUri(),
            headers: {
              ...authHeaders,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'isim': trimmed}),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 401) {
        await _clearLocal();
        _lastError = 'Oturum sona erdi. Tekrar giriş yapın.';
        return false;
      }
      if (res.statusCode != 200) {
        String detail = 'Ad güncellenemedi.';
        DateTime? nextAllowed;
        try {
          final body = jsonDecode(utf8.decode(res.bodyBytes));
          if (body is Map && body['detail'] != null) {
            detail = body['detail'].toString();
          }
          if (body is Map && body['isimDegistirilebilirAt'] != null) {
            nextAllowed =
                DateTime.tryParse('${body['isimDegistirilebilirAt']}');
          }
        } catch (_) {}
        _lastError = detail;
        if (nextAllowed != null && _user != null) {
          _user = _user!.copyWith(isimDegistirilebilirAt: nextAllowed);
          await _persist();
        }
        return false;
      }
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      if (json is! Map) {
        _lastError = 'Geçersiz sunucu yanıtı.';
        return false;
      }
      _user = UserModel.fromJson(Map<String, dynamic>.from(json));
      await _persist();
      return true;
    } catch (e) {
      debugPrint('Ad güncelleme: $e');
      _lastError = 'Sunucuya bağlanılamadı.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Anonim hesabı Google ile kalıcı hesaba bağlar; değilse normal giriş.
  Future<bool> signInWithGoogle() async {
    if (_busy) return false;
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _lastError = 'Giriş iptal edildi.';
        return false;
      }

      final googleAuth = await googleUser.authentication;
      var idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      OAuthCredential? credential;
      try {
        if (accessToken != null || idToken != null) {
          credential = GoogleAuthProvider.credential(
            accessToken: accessToken,
            idToken: idToken,
          );
          final fbUser = FirebaseAuth.instance.currentUser;
          final UserCredential cred;
          if (fbUser != null && fbUser.isAnonymous) {
            cred = await fbUser.linkWithCredential(credential);
          } else {
            cred = await FirebaseAuth.instance.signInWithCredential(credential);
          }
          final fbToken = await cred.user?.getIdToken(true);
          if (fbToken != null && fbToken.isNotEmpty) {
            idToken = fbToken;
          }
        }
      } catch (e) {
        debugPrint('FirebaseAuth: $e');
        final msg = e.toString();
        if (msg.contains('credential-already-in-use') ||
            msg.contains('email-already-in-use')) {
          try {
            final cred2 =
                await FirebaseAuth.instance.signInWithCredential(credential!);
            final fbToken = await cred2.user?.getIdToken(true);
            if (fbToken != null && fbToken.isNotEmpty) {
              idToken = fbToken;
            }
          } catch (e2) {
            debugPrint('FirebaseAuth fallback signIn: $e2');
            _lastError =
                'Google hesabı bağlanamadı. Tekrar deneyin.';
            return false;
          }
        } else
        if (!isAnonymous) {
          debugPrint('FirebaseAuth atlandı: $e');
        } else {
          _lastError = 'Google hesabı bağlanamadı. Tekrar deneyin.';
          return false;
        }
      }

      if ((idToken == null || idToken.isEmpty) &&
          (accessToken == null || accessToken.isEmpty)) {
        _lastError =
            'Google jetonu alınamadı. Uygulama SHA-1 / OAuth ayarını kontrol edin.';
        return false;
      }

      return _exchangeWithBackend(
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      debugPrint('Google giriş: $e');
      final msg = e.toString();
      if (msg.contains('ApiException: 10') || msg.contains('sign_in_failed')) {
        _lastError =
            'Google girişi yapılandırılmamış (SHA-1 / OAuth). '
            'Güncel google-services.json ile uygulamayi-yukle.bat çalıştırın. '
            'Detay: GOOGLE_GIRIS.md';
      } else if (msg.contains('SocketException') ||
          msg.contains('Failed host lookup') ||
          msg.contains('Connection refused') ||
          msg.contains('Timed out')) {
        _lastError =
            'Sunucuya ulaşılamadı (${ApiConfig.baseUrl}). PC ve telefon aynı Wi‑Fi’de olsun; basla.bat çalışsın.';
      } else {
        _lastError = 'Giriş başarısız. Tekrar deneyin.';
      }
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> _exchangeWithBackend({
    String? idToken,
    String? accessToken,
  }) async {
    try {
      final res = await http
          .post(
            ApiConfig.authGoogleUri(),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              if (idToken != null && idToken.isNotEmpty) 'id_token': idToken,
              if (accessToken != null && accessToken.isNotEmpty)
                'access_token': accessToken,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode != 200) {
        String detail = 'Sunucu girişi reddetti (${res.statusCode}).';
        try {
          final body = jsonDecode(utf8.decode(res.bodyBytes));
          if (body is Map && body['detail'] != null) {
            detail = body['detail'].toString();
          }
        } catch (_) {}
        _lastError = detail;
        return false;
      }

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! Map) {
        _lastError = 'Geçersiz sunucu yanıtı.';
        return false;
      }
      final token = body['token']?.toString();
      final userJson = body['user'];
      if (token == null || token.isEmpty || userJson is! Map) {
        _lastError = 'Eksik oturum bilgisi.';
        return false;
      }
      _token = token;
      _user = UserModel.fromJson(Map<String, dynamic>.from(userJson));
      await _persist();
      _syncPremiumSideEffects();
      notifyListeners();
      unawaited(DailyMiniExamService.instance.onAuthSessionChanged());
      return true;
    } catch (e) {
      debugPrint('Auth exchange: $e');
      _lastError =
          'Sunucuya bağlanılamadı (${ApiConfig.baseUrl}). basla.bat ile paneli açın.';
      return false;
    }
  }

  Future<void> signOut() async {
    final permanent = hasPermanentAccount;
    try {
      if (hasBackendSession && permanent) {
        await http
            .delete(ApiConfig.meUri(), headers: authHeaders)
            .timeout(const Duration(seconds: 8));
      }
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _clearLocal();
    notifyListeners();
    await ensureAnonymousSession();
    unawaited(DailyMiniExamService.instance.onAuthSessionChanged());
  }

  Future<void> _persist() async {
    final prefs = await AppPreferences.instance;
    if (_token != null) {
      await prefs.setString(_kToken, _token!);
    }
    if (_user != null) {
      await prefs.setString(_kUser, jsonEncode(_user!.toJson()));
    }
  }

  Future<void> _clearLocal() async {
    _token = null;
    _user = null;
    QuestionRatingService.instance.clear();
    final prefs = await AppPreferences.instance;
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
  }

  void _syncPremiumSideEffects() {
    final user = _user;
    if (user == null) return;
    DatabaseService.instance.setCurrentUser(user);
    if (!PlayBillingService.instance.premiumNotifier.value) {
      AdManager.instance.setPremium(PremiumService.instance.isPremium);
    }
  }
}
