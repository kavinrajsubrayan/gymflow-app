// lib/utils/firestore_debug_helper.dart - COMPATIBLE VERSION
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirestoreDebugHelper {
  static Future<void> debugFirebaseSetup() async {
    print('\n🔍 FIREBASE DEBUG REPORT');
    print('════════════════════════════════════════');

    try {
      // 1. Check Firebase initialization
      print('1️⃣ Firebase Initialization:');
      try {
        final FirebaseApp? app = Firebase.app();
        print('   ✅ Firebase app initialized: ${app?.name}');
        print('   🔧 Firebase options: ${app?.options}');
      } catch (e) {
        print('   ❌ Firebase not initialized: $e');
      }

      // 2. Check Firestore instance
      print('\n2️⃣ Firestore Instance:');
      final firestore = FirebaseFirestore.instance;
      print('   ✅ Firestore instance created');

      // 3. Check current user authentication
      print('\n3️⃣ User Authentication:');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('   ✅ User logged in: ${user.email}');
        print('   👤 User ID: ${user.uid}');
      } else {
        print('   ⚠️  No user logged in (this might affect security rules)');
      }

      // 4. Check equipment collection - COMPATIBLE VERSION
      print('\n4️⃣ Equipment Collection:');
      try {
        final equipmentRef = firestore.collection('equipment');
        print('   ✅ Equipment collection reference created');

        // Get limited number of documents to check
        final querySnapshot = await equipmentRef.limit(10).get();
        final docCount = querySnapshot.docs.length;
        print('   📊 Documents found: $docCount');

        if (docCount > 0) {
          print('   📝 Sample documents:');
          for (var doc in querySnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            print('     • ID: ${doc.id}');
            print('       Name: ${data['name'] ?? 'N/A'}');
            print('       Category: ${data['category'] ?? 'N/A'}');
            print('       Status: ${data['status'] ?? 'N/A'}');
            print('       Available: ${data['isAvailable'] ?? 'N/A'}');
            print('       Max Duration: ${data['maxDuration'] ?? 'N/A'} min');
            print('       ─────────────');
          }
        } else {
          print('   ⚠️  Equipment collection is EMPTY!');
          print(
              '   💡 Add equipment via Firebase Console or run createSampleEquipment()');
        }
      } catch (e) {
        print('   ❌ Error accessing equipment collection: $e');
        print('   📋 Error type: ${e.runtimeType}');

        // Check for permission denied
        if (e.toString().contains('PERMISSION_DENIED') ||
            e.toString().contains('permission-denied')) {
          print('   🔒 PERMISSION DENIED ERROR DETECTED!');
          print('   🔧 Your Firestore security rules might be blocking access');
          print('   📋 Go to: Firebase Console → Firestore → Rules tab');
          print('   💡 Temporary fix for development:');
          print('''
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
          ''');
        }

        // Check for missing index
        if (e.toString().contains('index')) {
          print('   🔍 INDEX ERROR DETECTED!');
          print('   💡 You need to create Firestore indexes');
          print('   📋 Go to: Firebase Console → Firestore → Indexes tab');
        }
      }

      // 5. Check Firestore settings
      print('\n5️⃣ Firestore Settings:');
      print('   📍 Firestore project: ${firestore.app.options.projectId}');
      print('   📦 Storage bucket: ${firestore.app.options.storageBucket}');

      // 6. Test a simple query
      print('\n6️⃣ Testing Simple Query:');
      try {
        final testDoc = await firestore
            .collection('test_collection')
            .doc('test_document')
            .get();

        if (testDoc.exists) {
          print('   ✅ Test document exists');
        } else {
          print('   ℹ️  Test document does not exist (this is normal)');
        }
      } catch (e) {
        print('   ❌ Test query failed: $e');
      }

      // 7. Check app configuration
      print('\n7️⃣ App Configuration:');
      try {
        final config = await Firebase.app().options;
        print('   ✅ Firebase config loaded');
        print(
            '   🔑 API Key starts with: ${config.apiKey?.substring(0, min(10, config.apiKey?.length ?? 0))}...');
        print(
            '   🆔 App ID starts with: ${config.appId?.substring(0, min(10, config.appId?.length ?? 0))}...');
      } catch (e) {
        print('   ❌ Error reading config: $e');
      }

      print('\n════════════════════════════════════════');
      print('🔍 DEBUG COMPLETE');
      print('════════════════════════════════════════\n');
    } catch (e) {
      print('❌ DEBUG HELPER ERROR: $e');
    }
  }

  static Future<void> checkFirestoreRules() async {
    print('\n🔒 CHECKING FIRESTORE SECURITY RULES');
    print('════════════════════════════════════════');

    try {
      final firestore = FirebaseFirestore.instance;
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Try to write (to check write permissions)
      print('📝 Testing write permission...');
      try {
        await firestore
            .collection('test_permissions')
            .doc('test_$timestamp')
            .set({
          'test': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
        print('   ✅ Write permission: GRANTED');

        // Clean up
        await firestore
            .collection('test_permissions')
            .doc('test_$timestamp')
            .delete();
      } catch (e) {
        print('   ❌ Write permission: DENIED - $e');
      }

      // Try to read (to check read permissions)
      print('\n📖 Testing read permission...');
      try {
        final snapshot = await firestore.collection('equipment').limit(1).get();
        print('   ✅ Read permission: GRANTED');
        print('   📊 Read ${snapshot.docs.length} documents');
      } catch (e) {
        print('   ❌ Read permission: DENIED - $e');
      }

      print('\n════════════════════════════════════════\n');
    } catch (e) {
      print('❌ Error checking rules: $e');
    }
  }

  static Future<void> createSampleEquipment() async {
    print('\n🎯 CREATING SAMPLE EQUIPMENT');
    print('════════════════════════════════════════');

    try {
      final firestore = FirebaseFirestore.instance;

      final sampleData = [
        {
          'name': 'Treadmill 2',
          'category': 'Cardio',
          'description': 'High-speed treadmill with interactive display',
          'maxDuration': 60,
          'status': 'available',
          'isAvailable': true,
          'currentUsers': 0,
          'maxCapacity': 1,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'name': 'Elliptical Trainer',
          'category': 'Cardio',
          'description':
              'Low-impact elliptical machine with 20 resistance levels',
          'maxDuration': 45,
          'status': 'available',
          'isAvailable': true,
          'currentUsers': 0,
          'maxCapacity': 1,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'name': 'Stationary Bike',
          'category': 'Cardio',
          'description': 'Ergonomic bike with adjustable resistance',
          'maxDuration': 60,
          'status': 'in_use',
          'isAvailable': false,
          'currentUsers': 1,
          'maxCapacity': 1,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'name': 'Dumbbell Rack',
          'category': 'Free Weights',
          'description': 'Complete set from 5-50 lbs',
          'maxDuration': 45,
          'status': 'available',
          'isAvailable': true,
          'currentUsers': 0,
          'maxCapacity': 5,
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      int successCount = 0;
      for (var data in sampleData) {
        try {
          await firestore.collection('equipment').add(data);
          print('   ✅ Added: ${data['name']}');
          successCount++;
        } catch (e) {
          print('   ❌ Failed to add ${data['name']}: $e');
        }
      }

      print(
          '\n📊 RESULTS: $successCount/${sampleData.length} equipment items created');
      if (successCount > 0) {
        print('✅ SAMPLE EQUIPMENT CREATED SUCCESSFULLY');
      } else {
        print('⚠️  No equipment could be created - check permissions');
      }
      print('════════════════════════════════════════\n');
    } catch (e) {
      print('❌ Error creating sample equipment: $e');
    }
  }

  static Future<void> printFirebaseConfig() async {
    print('\n⚙️ FIREBASE CONFIGURATION');
    print('════════════════════════════════════════');

    try {
      final app = Firebase.app();
      final options = app.options;

      print('📱 Platform: ${defaultTargetPlatform}');
      print('🔑 Project ID: ${options.projectId}');
      print('📦 Storage Bucket: ${options.storageBucket}');
      print(
          '🌍 API Key: ${options.apiKey?.substring(0, min(10, options.apiKey?.length ?? 0))}...');
      print(
          '📝 App ID: ${options.appId?.substring(0, min(10, options.appId?.length ?? 0))}...');
      print('📨 Messaging Sender ID: ${options.messagingSenderId}');

      print('\n✅ Firebase configuration loaded');
      print('════════════════════════════════════════\n');
    } catch (e) {
      print('❌ Error reading Firebase config: $e');
    }
  }

  static Future<void> checkInternetConnection() async {
    print('\n🌐 CHECKING INTERNET CONNECTION');
    print('════════════════════════════════════════');

    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        print('✅ Internet connection: ACTIVE');
      } else {
        print('❌ Internet connection: NO RESPONSE');
      }
    } on SocketException catch (_) {
      print('❌ Internet connection: OFFLINE');
      print('💡 Check your network connection');
    }

    print('════════════════════════════════════════\n');
  }

  static Future<void> printAllEquipment() async {
    print('\n📋 LISTING ALL EQUIPMENT');
    print('════════════════════════════════════════');

    try {
      final firestore = FirebaseFirestore.instance;
      final querySnapshot = await firestore.collection('equipment').get();

      if (querySnapshot.docs.isEmpty) {
        print('⚠️  No equipment found in Firestore');
        print('💡 Run createSampleEquipment() to add test data');
        return;
      }

      print('📊 Total equipment: ${querySnapshot.docs.length}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        print('• ${data['name'] ?? 'Unnamed'}');
        print('  Category: ${data['category'] ?? 'N/A'}');
        print('  Status: ${data['status'] ?? 'N/A'}');
        print('  Available: ${data['isAvailable'] ?? 'N/A'}');
        print(
            '  Users: ${data['currentUsers'] ?? 0}/${data['maxCapacity'] ?? 1}');
        print('  Max Duration: ${data['maxDuration'] ?? 'N/A'} min');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      print('════════════════════════════════════════\n');
    } catch (e) {
      print('❌ Error listing equipment: $e');
    }
  }

  static Future<void> clearTestData() async {
    print('\n🗑️  CLEARING TEST DATA');
    print('════════════════════════════════════════');

    try {
      final firestore = FirebaseFirestore.instance;

      // Clear test_permissions collection
      final testSnapshot = await firestore.collection('test_permissions').get();
      for (var doc in testSnapshot.docs) {
        await doc.reference.delete();
      }
      print('✅ Cleared test_permissions collection');

      print('════════════════════════════════════════\n');
    } catch (e) {
      print('❌ Error clearing test data: $e');
    }
  }

  // Helper function
  static int min(int a, int b) => a < b ? a : b;
}
