enum CloudProvider { google, apple, none }

/// Bulut senkronizasyon iskeleti — production'da Firebase/Supabase ile genişletilir.
class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  CloudProvider _provider = CloudProvider.none;
  String? _userEmail;
  DateTime? _lastSync;

  CloudProvider get provider => _provider;
  String? get userEmail => _userEmail;
  DateTime? get lastSync => _lastSync;
  bool get isConnected => _provider != CloudProvider.none;

  Future<bool> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _provider = CloudProvider.google;
    _userEmail = 'kullanici@gmail.com';
    _lastSync = DateTime.now();
    return true;
  }

  Future<bool> signInWithApple() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _provider = CloudProvider.apple;
    _userEmail = 'kullanici@icloud.com';
    _lastSync = DateTime.now();
    return true;
  }

  Future<void> syncNow() async {
    if (!isConnected) return;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _lastSync = DateTime.now();
  }

  Future<void> signOut() async {
    _provider = CloudProvider.none;
    _userEmail = null;
    _lastSync = null;
  }
}
