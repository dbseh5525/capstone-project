import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        throw UnsupportedError(
          'Android 앱이 아직 Firebase 콘솔에 등록되지 않았습니다. Android 앱 등록 후 이 파일에 android 옵션을 추가하세요.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions는 현재 iOS만 지원합니다.',
        );
    }
  }

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDuTbBdRNwww2SxJ1q_UEa9T8w-PyHmEEc',
    appId: '1:564336576115:ios:aa910de3614b2e399d4c06',
    messagingSenderId: '564336576115',
    projectId: 'mood-12672',
    storageBucket: 'mood-12672.firebasestorage.app',
    iosBundleId: 'com.a1hajo.mira',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCJ9uCa_29meCHl9q1vC_O4tMzz2o301Xw',
    appId: '1:564336576115:web:ad0a7591d020d6469d4c06',
    messagingSenderId: '564336576115',
    projectId: 'mood-12672',
    authDomain: 'mood-12672.firebaseapp.com',
    storageBucket: 'mood-12672.firebasestorage.app',
    measurementId: 'G-NKD9PSKW5R',
  );
}
