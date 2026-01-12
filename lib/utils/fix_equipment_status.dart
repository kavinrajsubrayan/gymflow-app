// lib/utils/fix_equipment_status.dart
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> fixEquipmentStatusForSingleMachine() async {
  final firestore = FirebaseFirestore.instance;

  print('\n🔧 FIXING EQUIPMENT STATUS...');
  print('════════════════════════════════════════');
  print('CHANGING: "Fully Booked" → "In Use"');
  print('WHEN: 1 person using single machine');
  print('════════════════════════════════════════');

  try {
    // Get all equipment
    final equipmentSnapshot = await firestore.collection('equipment').get();

    int fixedCount = 0;

    for (var doc in equipmentSnapshot.docs) {
      final data = doc.data();
      final name = data['name'] as String? ?? 'Unknown';
      final currentStatus = data['status'] as String? ?? 'available';
      final currentUsers = data['currentUsers'] as int? ?? 0;

      // Fix 1: If status is "fully_booked" but only 1 user, change to "in_use"
      if (currentStatus == 'fully_booked' && currentUsers == 1) {
        await doc.reference.update({
          'status': 'in_use',
          'isAvailable': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ FIXED $name: fully_booked → in_use');
        fixedCount++;
      }

      // Fix 2: Make sure maxCapacity is 1 (single machine)
      final maxCapacity = data['maxCapacity'] as int? ?? 1;
      if (maxCapacity != 1) {
        await doc.reference.update({
          'maxCapacity': 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        print('✅ FIXED $name: maxCapacity = 1 (single machine)');
      }
    }

    print('════════════════════════════════════════');
    print('🎉 FIX COMPLETE!');
    print('Fixed $fixedCount equipment items');
    print('NOW: 1 user = ORANGE "In Use"');
    print('════════════════════════════════════════\n');

    return;
  } catch (e) {
    print('❌ Error fixing equipment: $e');
    rethrow;
  }
}
