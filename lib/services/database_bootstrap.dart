import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Windows/macOS/Linux geliştirme ortamında SQLite FFI başlatır.
/// Android/iOS'ta sqflite varsayılan factory kullanılır.
Future<void> initializeDatabaseFactory() async {
  if (kIsWeb) return;

  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
