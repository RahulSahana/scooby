// File generated for Scooby Firebase project.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
          'DefaultFirebaseOptions have not been configured for Linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBy94PquSUWQ8ydlTRphlo-2DMTJ0SXNZU',
    appId: '1:193673341582:android:ab60b0ea5b7cf6d5dbf7df',
    messagingSenderId: '193673341582',
    projectId: 'scooby-ce098',
    storageBucket: 'scooby-ce098.firebasestorage.app',
  );
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC7yzJVRnMV4xzwHBzpJdJfRebyC24skyQ',
    appId: '1:193673341582:web:32e76c109b320c98dbf7df',
    messagingSenderId: '193673341582',
    projectId: 'scooby-ce098',
    authDomain: 'scooby-ce098.firebaseapp.com',
    storageBucket: 'scooby-ce098.firebasestorage.app',
    measurementId: 'G-BBYJX8GWF5',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAbXPxV6W_EYO1htwdh-RFzTNJ0RAvqDyU',
    appId: '1:193673341582:ios:ff7e468009100d9adbf7df',
    messagingSenderId: '193673341582',
    projectId: 'scooby-ce098',
    storageBucket: 'scooby-ce098.firebasestorage.app',
    androidClientId: '193673341582-vg5mnta6v4fh89pt4e6urh45d60bqiuv.apps.googleusercontent.com',
    iosClientId: '193673341582-40hc1cbme03agnrc3helu7vt17cepnpv.apps.googleusercontent.com',
    iosBundleId: 'com.example.scooby',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAbXPxV6W_EYO1htwdh-RFzTNJ0RAvqDyU',
    appId: '1:193673341582:ios:ff7e468009100d9adbf7df',
    messagingSenderId: '193673341582',
    projectId: 'scooby-ce098',
    storageBucket: 'scooby-ce098.firebasestorage.app',
    androidClientId: '193673341582-vg5mnta6v4fh89pt4e6urh45d60bqiuv.apps.googleusercontent.com',
    iosClientId: '193673341582-40hc1cbme03agnrc3helu7vt17cepnpv.apps.googleusercontent.com',
    iosBundleId: 'com.example.scooby',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyC7yzJVRnMV4xzwHBzpJdJfRebyC24skyQ',
    appId: '1:193673341582:web:ceaf7c62e78630f9dbf7df',
    messagingSenderId: '193673341582',
    projectId: 'scooby-ce098',
    authDomain: 'scooby-ce098.firebaseapp.com',
    storageBucket: 'scooby-ce098.firebasestorage.app',
    measurementId: 'G-YZTTSCJLBG',
  );
}
