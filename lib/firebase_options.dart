import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAcN1IADqkCF7QNNQHYU2uanOwWHksCUEo',
    appId: '1:144939315376:android:0f5c3ec1a005940eec0b75',
    messagingSenderId: '144939315376',
    projectId: 'meritminder-3bc86',
    storageBucket: 'meritminder-3bc86.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDYRp7ErT9Fk1OwjE4KYEC-1eilyH7n-rQ',
    appId: '1:144939315376:ios:b96171143f5ce91aec0b75',
    messagingSenderId: '144939315376',
    projectId: 'meritminder-3bc86',
    storageBucket: 'meritminder-3bc86.firebasestorage.app',
    iosClientId: '144939315376-glunicbsgmbo541bhi0l97vo984jfn8b.apps.googleusercontent.com',
    iosBundleId: 'com.meritminder.app',
  );
}
