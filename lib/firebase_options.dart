// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web not configured');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const FirebaseOptions(
          apiKey: 'AIzaSyBfALI2yS81_FFzM6Bq09YCVwsTTxdTAxM',
          appId: '1:643978776615:android:034933f50e699aab593e02',
          messagingSenderId: '643978776615',
          projectId: 'carpool-app-3d16d',
          storageBucket: 'carpool-app-3d16d.firebasestorage.app',
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }
}