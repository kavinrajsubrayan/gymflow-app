// lib/services/equipment_service.dart - UPDATED VERSION
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/equipment.dart';

class EquipmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get real-time stream of all equipment with improved error handling
  Stream<List<Equipment>> getEquipmentStream() {
    print('📡 Creating equipment stream from Firestore...');

    return _firestore
        .collection('equipment')
        .snapshots(includeMetadataChanges: true)
        .handleError((error) {
      print('❌ Firestore stream error: $error');
      print('📋 Error type: ${error.runtimeType}');

      // Provide more specific error messages
      if (error.toString().contains('permission-denied')) {
        throw Exception(
            'Permission denied. Please check Firestore security rules.');
      } else if (error.toString().contains('unavailable')) {
        throw Exception(
            'Firestore unavailable. Please check your internet connection.');
      } else {
        throw Exception('Firestore error: ${error.toString()}');
      }
    }).map((snapshot) {
      print('📊 Raw Firestore snapshot received:');
      print('  • Document count: ${snapshot.docs.length}');
      print('  • Has pending writes: ${snapshot.metadata.hasPendingWrites}');
      print('  • Is from cache: ${snapshot.metadata.isFromCache}');

      // Show warning if data is from cache (offline)
      if (snapshot.metadata.isFromCache) {
        print('⚠️  Data loaded from CACHE (offline mode)');
      } else {
        print('✅ Data loaded from SERVER (online)');
      }

      if (snapshot.docs.isEmpty) {
        print('⚠️  WARNING: No documents found in equipment collection');
        print('💡 Check if:');
        print('   1. "equipment" collection exists in Firestore');
        print('   2. Collection name is spelled correctly');
        print('   3. Firestore rules allow read access');
        print('   4. Data has been added to the collection');
        return [];
      }

      final equipmentList = <Equipment>[];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();

          // Debug print each document
          print('📝 Processing equipment document:');
          print('  • Document ID: ${doc.id}');
          print('  • Name: ${data['name']}');
          print('  • Status: ${data['status']}');
          print('  • Available: ${data['isAvailable']}');
          print('  • Current Users: ${data['currentUsers']}');
          print('  • Max Capacity: ${data['maxCapacity']}');

          // Validate required fields
          if (data['name'] == null || data['name'].toString().isEmpty) {
            print('⚠️  Skipping: Equipment missing "name" field');
            continue;
          }

          final equipment = Equipment.fromMap(doc.id, data);
          equipmentList.add(equipment);
          print('✅ Successfully parsed: ${equipment.name}');
        } catch (e) {
          print('❌ Error parsing equipment document ${doc.id}: $e');
          print('   Skipping this document...');
          continue;
        }
      }

      print('✅ Successfully processed ${equipmentList.length} equipment items');

      // Log available equipment count - ADDED THIS
      final availableCount =
          equipmentList.where((e) => e.isAvailableNow).length;
      print('🎯 Available equipment: $availableCount');
      print('🚫 In use equipment: ${equipmentList.length - availableCount}');

      if (equipmentList.isNotEmpty) {
        print(
            '📋 Equipment categories: ${equipmentList.map((e) => e.category).toSet().toList()}');
      }

      return equipmentList;
    });
  }

  // Get equipment by category with improved error handling
  Stream<List<Equipment>> getEquipmentByCategory(String category) {
    print('📡 Getting equipment for category: "$category"');

    if (category == 'All') {
      print('📊 Returning ALL equipment');
      return getEquipmentStream();
    }

    return _firestore
        .collection('equipment')
        .where('category', isEqualTo: category)
        .snapshots(includeMetadataChanges: true)
        .handleError((error) {
      print('❌ Error in category stream for "$category": $error');
      throw Exception('Failed to load category "$category": $error');
    }).map((snapshot) {
      print('📊 Category "$category" snapshot: ${snapshot.docs.length} docs');
      print('   From cache: ${snapshot.metadata.isFromCache}');

      if (snapshot.docs.isEmpty) {
        print('ℹ️  No equipment found in category "$category"');
        return [];
      }

      return snapshot.docs.map((doc) {
        try {
          final data = doc.data();
          print('📝 Category equipment: ${data['name']}');
          return Equipment.fromMap(doc.id, data);
        } catch (e) {
          print('❌ Error parsing document in category "$category": $e');
          rethrow;
        }
      }).toList();
    });
  }

  // Test Firestore connection
  Future<bool> testConnection() async {
    print('🔍 Testing Firestore connection...');

    try {
      await _firestore
          .collection('equipment')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      print('✅ Firestore connection successful');
      return true;
    } catch (e) {
      print('❌ Firestore connection failed: $e');
      return false;
    }
  }

  // Get single equipment by ID
  Future<Equipment?> getEquipmentById(String equipmentId) async {
    print('🔍 Getting equipment by ID: $equipmentId');

    try {
      final doc = await _firestore
          .collection('equipment')
          .doc(equipmentId)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists) {
        print('❌ Equipment not found with ID: $equipmentId');
        return null;
      }

      final data = doc.data()!;
      print('✅ Found equipment: ${data['name']}');
      return Equipment.fromMap(doc.id, data);
    } catch (e) {
      print('❌ Error getting equipment by ID: $e');
      return null;
    }
  }

  // Update equipment status
  Future<void> updateEquipmentStatus(String equipmentId, String status) async {
    print('🔄 Updating equipment status: $equipmentId -> $status');

    try {
      final isAvailable = status == 'available';

      await _firestore.collection('equipment').doc(equipmentId).update({
        'status': status,
        'isAvailable': isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Equipment status updated successfully');
    } catch (e) {
      print('❌ Error updating equipment status: $e');
      throw Exception('Failed to update equipment status: $e');
    }
  }

  // Update current users count
  Future<void> updateCurrentUsers(String equipmentId, int currentUsers) async {
    print('👥 Updating current users for $equipmentId: $currentUsers');

    try {
      String status;
      bool isAvailable;

      if (currentUsers == 0) {
        status = 'available';
        isAvailable = true;
      } else if (currentUsers >= 1) {
        status = 'in_use';
        isAvailable = false;
      } else {
        status = 'available';
        isAvailable = true;
      }

      await _firestore.collection('equipment').doc(equipmentId).update({
        'currentUsers': currentUsers,
        'status': status,
        'isAvailable': isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Current users updated successfully');
    } catch (e) {
      print('❌ Error updating current users: $e');
      throw Exception('Failed to update current users: $e');
    }
  }

  // Initialize sample equipment data (for testing/development)
  Future<void> initializeSampleEquipment() async {
    print('\n🎯 INITIALIZING SAMPLE EQUIPMENT DATA');
    print('════════════════════════════════════════');

    try {
      // Check if equipment collection already has data
      final snapshot = await _firestore
          .collection('equipment')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));

      if (snapshot.docs.isNotEmpty) {
        print('📊 Equipment collection already has data');
        print('   Skipping sample data initialization');
        print('   Current document count: ${snapshot.docs.length}');
        return;
      }

      print('📝 Creating sample equipment data...');

      final sampleEquipment = [
        {
          'name': 'Treadmill 1',
          'category': 'Cardio',
          'description':
              'High-speed treadmill with interactive display, cooling fans, and heart rate monitoring',
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
              'Low-impact elliptical machine with 20 resistance levels and pre-programmed workouts',
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
          'description':
              'Ergonomic stationary bike with adjustable seat and resistance controls',
          'maxDuration': 60,
          'status': 'available',
          'isAvailable': true,
          'currentUsers': 0,
          'maxCapacity': 1,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'name': 'Dumbbell Rack',
          'category': 'Free Weights',
          'description':
              'Complete set of dumbbells from 5lbs to 50lbs with organized rack',
          'maxDuration': 45,
          'status': 'available',
          'isAvailable': true,
          'currentUsers': 0,
          'maxCapacity': 5,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'name': 'Squat Rack',
          'category': 'Strength',
          'description': 'Power squat rack with safety bars and weight plates',
          'maxDuration': 60,
          'status': 'available',
          'isAvailable': true,
          'currentUsers': 0,
          'maxCapacity': 1,
          'createdAt': FieldValue.serverTimestamp(),
        },
        {
          'name': 'Cable Machine',
          'category': 'Functional',
          'description':
              'Multi-functional cable machine with various attachments',
          'maxDuration': 45,
          'status': 'available',
          'isAvailable': true,
          'currentUsers': 0,
          'maxCapacity': 2,
          'createdAt': FieldValue.serverTimestamp(),
        },
      ];

      // Use batch write for better performance
      final batch = _firestore.batch();

      for (final equipment in sampleEquipment) {
        final docRef = _firestore.collection('equipment').doc();
        batch.set(docRef, equipment);
        print('   ✅ Queued: ${equipment['name']} (${equipment['category']})');
      }

      await batch.commit();

      print('\n🎉 SAMPLE DATA INITIALIZATION COMPLETE!');
      print('   Added ${sampleEquipment.length} equipment items');
      print('════════════════════════════════════════\n');
    } on FirebaseException catch (e) {
      print('❌ Firebase Error initializing sample equipment:');
      print('   Code: ${e.code}');
      print('   Message: ${e.message}');
      print('\n💡 Common solutions:');
      if (e.code == 'permission-denied') {
        print('   → Update Firestore security rules to allow writes');
      } else if (e.code == 'unavailable') {
        print('   → Check your internet connection');
      }
      rethrow;
    } catch (e) {
      print('❌ Error initializing sample equipment: $e');
      print('💡 Make sure:');
      print('   1. Firestore is properly configured');
      print('   2. You have write permissions');
      print('   3. Internet connection is stable');
      rethrow;
    }
  }

  // Get equipment statistics
  Future<Map<String, dynamic>> getEquipmentStats() async {
    print('📊 Getting equipment statistics...');

    try {
      final snapshot = await _firestore
          .collection('equipment')
          .get()
          .timeout(const Duration(seconds: 10));

      final total = snapshot.docs.length;
      final available = snapshot.docs
          .where((doc) => doc.data()['isAvailable'] == true)
          .length;
      final inUse =
          snapshot.docs.where((doc) => doc.data()['status'] == 'in_use').length;
      final booked = snapshot.docs
          .where((doc) => doc.data()['status'] == 'fully_booked')
          .length;

      // Count by category
      final categories = <String, int>{};
      for (var doc in snapshot.docs) {
        final category = doc.data()['category'] as String? ?? 'Unknown';
        categories[category] = (categories[category] ?? 0) + 1;
      }

      final stats = {
        'total': total,
        'available': available,
        'in_use': inUse,
        'fully_booked': booked,
        'categories': categories,
      };

      print('✅ Equipment statistics:');
      print('   Total: $total');
      print('   Available: $available');
      print('   In Use: $inUse');
      print('   Fully Booked: $booked');
      print('   Categories: $categories');

      return stats;
    } catch (e) {
      print('❌ Error getting equipment stats: $e');
      return {
        'total': 0,
        'available': 0,
        'in_use': 0,
        'fully_booked': 0,
        'categories': {},
      };
    }
  }
}
