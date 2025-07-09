import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAiosIrqYHSh_LwYAVAiPx8ptgpFMG09MA',
    appId: '1:885681443452:web:46163df122cb27c428eff9',
    messagingSenderId: '885681443452',
    projectId: 'grevia-7b7af',
    authDomain: 'grevia-7b7af.firebaseapp.com',
    storageBucket: 'grevia-7b7af.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAiosIrqYHSh_LwYAVAiPx8ptgpFMG09MA',
    appId: '1:885681443452:android:46163df122cb27c428eff9',
    messagingSenderId: '885681443452',
    projectId: 'grevia-7b7af',
    storageBucket: 'grevia-7b7af.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAiosIrqYHSh_LwYAVAiPx8ptgpFMG09MA',
    appId: '1:885681443452:ios:46163df122cb27c428eff9',
    messagingSenderId: '885681443452',
    projectId: 'grevia-7b7af',
    storageBucket: 'grevia-7b7af.firebasestorage.app',
    iosBundleId: 'com.app.grevia',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAiosIrqYHSh_LwYAVAiPx8ptgpFMG09MA',
    appId: '1:885681443452:ios:46163df122cb27c428eff9',
    messagingSenderId: '885681443452',
    projectId: 'grevia-7b7af',
    storageBucket: 'grevia-7b7af.firebasestorage.app',
    iosBundleId: 'com.app.grevia',
  );
}
