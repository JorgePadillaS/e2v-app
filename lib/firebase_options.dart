import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Derived from the owner's MaxVolt Android and iOS configuration files.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Firebase web no está configurado.');
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => throw UnsupportedError(
        'Firebase no está configurado para esta plataforma.',
      ),
    };
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyCV7GovxqIh4nVw8X9a2nOaja-BAHSDTK8',
    appId: '1:92734497090:android:b45c65d46168bc0108e8db',
    messagingSenderId: '92734497090',
    projectId: 'maxvolt-ac105',
    storageBucket: 'maxvolt-ac105.firebasestorage.app',
  );
  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyCf4I0bLQOpSGvqGh-c1TdNaYxGvcd8cu4',
    appId: '1:92734497090:ios:1ad22a04d1e1af6608e8db',
    messagingSenderId: '92734497090',
    projectId: 'maxvolt-ac105',
    storageBucket: 'maxvolt-ac105.firebasestorage.app',
    iosBundleId: 'net.maxvolt.app',
    iosClientId: '92734497090-vp5rie0jtq9vpnm1rhnlfu6murm0ccqi.apps.googleusercontent.com',
  );
}
