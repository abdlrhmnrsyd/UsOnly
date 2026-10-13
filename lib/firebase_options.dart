// File generated for UsOnly Flutter application.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDIl-yZfhh49VAWDi6F4oj6cbMl2WB-bfE',
    appId: '1:104677632642:web:b0b558484037177eb5e29b',
    messagingSenderId: '104677632642',
    projectId: 'usonly-aplication',
    authDomain: 'usonly-aplication.firebaseapp.com',
    storageBucket: 'usonly-aplication.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD7qe3b4DE9GyKKmF4Q3WeWr6tf2kSlg3Q',
    appId: '1:104677632642:android:021627cd1688689bb5e29b',
    messagingSenderId: '104677632642',
    projectId: 'usonly-aplication',
    storageBucket: 'usonly-aplication.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBrPv9iBoJdYnpya9axprhGpX2yePpsmHg',
    appId: '1:104677632642:ios:4ddcd246f11306fab5e29b',
    messagingSenderId: '104677632642',
    projectId: 'usonly-aplication',
    storageBucket: 'usonly-aplication.firebasestorage.app',
    iosBundleId: 'com.usonly.app.usonly',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBrPv9iBoJdYnpya9axprhGpX2yePpsmHg',
    appId: '1:104677632642:ios:4ddcd246f11306fab5e29b',
    messagingSenderId: '104677632642',
    projectId: 'usonly-aplication',
    storageBucket: 'usonly-aplication.firebasestorage.app',
    iosBundleId: 'com.usonly.app.usonly',
  );
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyA_placeholder_usonly_windows_key',
    appId: '1:100000000000:web:usonlywindowsid',
    messagingSenderId: '100000000000',
    projectId: 'usonly-app',
    authDomain: 'usonly-app.firebaseapp.com',
    storageBucket: 'usonly-app.appspot.com',
  );
}
