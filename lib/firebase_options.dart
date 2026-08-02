// File generated in the style of FlutterFire CLI (`flutterfire configure`).
//
// Android values come from app/google-services.json; Web values come from the Web app
// registered in Firebase Console > Project Settings > Your apps. Both point at the same
// Firebase project ("pantunconnect") shared with the Kotlin app.
//
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - run `flutterfire configure`.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyC7Txv9ycVSwtTyoRW37QQii6Kraoh1Bew',
    appId: '1:848832142692:android:0f62516380e12616622e71',
    messagingSenderId: '848832142692',
    projectId: 'pantunconnect',
    storageBucket: 'pantunconnect.firebasestorage.app',
  );

  // Real values from the "PANTUN-CONNECT Web" app registered in Firebase Console.
  static const web = FirebaseOptions(
    apiKey: 'AIzaSyDynxylvbQX6cPAMOb_tDEH_j-1meVUafQ',
    appId: '1:848832142692:web:db05b2b344644c9f622e71',
    messagingSenderId: '848832142692',
    projectId: 'pantunconnect',
    storageBucket: 'pantunconnect.firebasestorage.app',
    authDomain: 'pantunconnect.firebaseapp.com',
  );
}
