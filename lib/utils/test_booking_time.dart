// lib/utils/test_booking_time.dart - For testing
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> debugBookingTimes() async {
  final firestore = FirebaseFirestore.instance;

  print('\n🕒 DEBUG: Checking booking times...');
  print('════════════════════════════════════════');

  final now = DateTime.now();
  print('⏰ Current time: $now');
  print('   Hour: ${now.hour}, Minute: ${now.minute}');

  // Get all bookings
  final bookingsSnapshot = await firestore
      .collection('equipment_bookings')
      .get();

  for (var doc in bookingsSnapshot.docs) {
    final data = doc.data();
    final equipmentName = data['equipmentName'] as String? ?? 'Unknown';
    final date = (data['date'] as Timestamp).toDate();
    final startTime = data['startTime'] as String? ?? '00:00';
    final duration = data['duration'] as int? ?? 30;
    final isCancelled = data['isCancelled'] as bool? ?? false;

    // Parse time
    final timeParts = startTime.split(':');
    final startDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(timeParts[0]),
      int.parse(timeParts[1]),
    );

    final endDateTime = startDateTime.add(Duration(minutes: duration));

    print('\n📅 Booking: $equipmentName');
    print('   Date: $date');
    print('   Start: $startDateTime');
    print('   End: $endDateTime');
    print('   Duration: $duration minutes');
    print('   Cancelled: $isCancelled');

    // Check status
    if (now.isBefore(startDateTime)) {
      print(
        '   🔵 Status: UPCOMING (starts in ${startDateTime.difference(now).inMinutes} min)',
      );
    } else if (now.isAfter(endDateTime)) {
      print(
        '   🔴 Status: ENDED (${now.difference(endDateTime).inMinutes} min ago)',
      );
    } else {
      print(
        '   🟠 Status: ACTIVE NOW (ends in ${endDateTime.difference(now).inMinutes} min)',
      );
    }
  }

  print('════════════════════════════════════════\n');
}
