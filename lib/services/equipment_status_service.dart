// lib/services/equipment_status_service.dart - NEW FILE
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EquipmentStatusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Update equipment status when booking starts/ends
  Future<void> updateEquipmentStatusOnBooking(
      String equipmentId, bool isBooking) async {
    try {
      final equipmentRef = _firestore.collection('equipment').doc(equipmentId);
      final equipmentDoc = await equipmentRef.get();

      if (!equipmentDoc.exists) {
        print('❌ Equipment not found: $equipmentId');
        return;
      }

      final data = equipmentDoc.data()!;
      final currentUsers = data['currentUsers'] as int? ?? 0;
      final maxCapacity = data['maxCapacity'] as int? ?? 1;

      String newStatus;
      bool isAvailable;
      int newUserCount;

      if (isBooking) {
        // Booking starting
        newUserCount = currentUsers + 1;
        if (newUserCount >= maxCapacity) {
          newStatus = 'fully_booked';
          isAvailable = false;
        } else {
          newStatus = 'in_use';
          isAvailable = false;
        }
      } else {
        // Booking ending
        newUserCount = currentUsers > 0 ? currentUsers - 1 : 0;
        if (newUserCount <= 0) {
          newStatus = 'available';
          isAvailable = true;
        } else if (newUserCount >= maxCapacity) {
          newStatus = 'fully_booked';
          isAvailable = false;
        } else {
          newStatus = 'in_use';
          isAvailable = false;
        }
      }

      await equipmentRef.update({
        'status': newStatus,
        'isAvailable': isAvailable,
        'currentUsers': newUserCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('🔄 Equipment $equipmentId status updated:');
      print('   • New status: $newStatus');
      print('   • Available: $isAvailable');
      print('   • Users: $newUserCount/$maxCapacity');
    } catch (e) {
      print('❌ Error updating equipment status: $e');
    }
  }

  // Check and update all equipment status
  Future<void> syncAllEquipmentStatus() async {
    try {
      print('🔄 Syncing all equipment status...');

      final equipmentSnapshot = await _firestore.collection('equipment').get();

      for (var doc in equipmentSnapshot.docs) {
        final equipmentId = doc.id;
        final data = doc.data();
        final currentUsers = data['currentUsers'] as int? ?? 0;
        final maxCapacity = data['maxCapacity'] as int? ?? 1;

        String correctStatus;
        bool correctAvailability;

        if (currentUsers <= 0) {
          correctStatus = 'available';
          correctAvailability = true;
        } else if (currentUsers >= maxCapacity) {
          correctStatus = 'fully_booked';
          correctAvailability = false;
        } else {
          correctStatus = 'in_use';
          correctAvailability = false;
        }

        // Update if status is incorrect
        if (data['status'] != correctStatus ||
            data['isAvailable'] != correctAvailability) {
          await _firestore.collection('equipment').doc(equipmentId).update({
            'status': correctStatus,
            'isAvailable': correctAvailability,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          print('✅ Fixed equipment ${data['name']}:');
          print(
              '   • Old: ${data['status']} (available: ${data['isAvailable']})');
          print('   • New: $correctStatus (available: $correctAvailability)');
        }
      }

      print('✅ Equipment status sync completed');
    } catch (e) {
      print('❌ Error syncing equipment status: $e');
    }
  }
}
