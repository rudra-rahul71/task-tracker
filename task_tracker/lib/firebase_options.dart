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
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the flutterfire cli.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return ios; // fallback for now
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDpvOQAzUhWjHOugcUA0GCjH9BEVDH48sE',
    appId: '1:507969319719:android:a400f302193b357974af02',
    messagingSenderId: '507969319719',
    projectId: 'proof-d3958',
    storageBucket: 'proof-d3958.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCGUuhdKoyccoHArPsMXFz5amFaGERmEpM',
    appId: '1:507969319719:ios:e14e14c04d54c94074af02',
    messagingSenderId: '507969319719',
    projectId: 'proof-d3958',
    storageBucket: 'proof-d3958.firebasestorage.app',
    iosBundleId: 'com.rudra.ecosystem',
  );
}
