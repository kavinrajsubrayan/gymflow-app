// lib/firebase_options.dart - CORRECTED VERSION
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// IMPORTANT: Replace these values with your ACTUAL Firebase project credentials
/// Get them from: Firebase Console > Project Settings > Your apps
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
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

  // CORRECTED Android Configuration
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBdP7pL5r0BvZ8XqQ9WtQ8b6sYV7mJk8nA',
    appId: '1:128360017777:android:a6e1e0d7a3f9f5bcd4c8e', // Fixed format
    messagingSenderId: '128360017777',
    projectId: 'gym-flow-sfma', // Made consistent (lowercase)
    storageBucket: 'gym-flow-sfma.firebasestorage.app',
  );

  // CORRECTED iOS Configuration
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBdP7pL5r0BvZ8XqQ9WtQ8b6sYV7mJk8nA',
    appId: '1:128360017777:ios:a6e1e0d7a3f9f5bcd4c8e', // Fixed format
    messagingSenderId: '128360017777',
    projectId: 'gym-flow-sfma', // Made consistent (lowercase)
    storageBucket: 'gym-flow-sfma.firebasestorage.app',
    iosBundleId: 'com.example.gymflow',
  );
}

/* 
═══════════════════════════════════════════════════════════════
⚠️  CRITICAL: YOU MUST UPDATE THESE VALUES! ⚠️
═══════════════════════════════════════════════════════════════

The values above are CORRECTED but may still not be your actual
Firebase project credentials. Follow these steps:

📋 STEP 1: Get Your Real Firebase Credentials
────────────────────────────────────────────────
1. Go to https://console.firebase.google.com
2. Select your "gym-flow-sfma" project
3. Click the gear icon (⚙️) → Project settings
4. Scroll down to "Your apps"
5. Select your Android/iOS app
6. Copy the EXACT values shown

📋 STEP 2: Alternative Method (Recommended)
────────────────────────────────────────────────
Run this command in your project terminal:

   flutterfire configure

This will automatically generate the correct firebase_options.dart

📋 STEP 3: Verify google-services.json (Android)
────────────────────────────────────────────────
Make sure you have downloaded the correct google-services.json:

1. Firebase Console → Project Settings → Your apps
2. Download google-services.json for Android
3. Place it in: android/app/google-services.json

The file should contain the SAME project_id and storage_bucket
as shown in firebase_options.dart

📋 STEP 4: Common Issues
────────────────────────────────────────────────
❌ "App ID format is invalid"
   → Your appId should look like: 1:123456:android:abc123def456
   
❌ "Project not found"
   → Check projectId matches Firebase Console exactly
   
❌ "Permission denied"
   → Update Firestore Security Rules (see below)

═══════════════════════════════════════════════════════════════
*/
