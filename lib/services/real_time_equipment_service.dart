// lib/services/real_time_equipment_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class RealTimeEquipmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _updateTimer;
  bool _isUpdating = false;
  bool _started = false;

  // In-memory cache
  final Map<String, Map<String, dynamic>> _equipmentStatusCache = {};

  /// PUBLIC: start service (SAFE)
  void startRealTimeUpdates() {
    if (_started) return;
    _started = true;

    print('⏳ Scheduling real-time equipment service...');

    // Delay start until UI is rendered
    Future.delayed(const Duration(seconds: 2), () {
      print('🚀 Real-time equipment service started');

      // Periodic update (every 30s, not 10s)
      _updateTimer =
          Timer.periodic(const Duration(seconds: 30), (_) => _safeUpdateAll());

      // Initial update
      _safeUpdateAll();

      // Listen to booking changes (throttled)
      _listenToBookingChanges();
    });
  }

  void stop() {
    _updateTimer?.cancel();
    _updateTimer = null;
    _started = false;
    print('🛑 Real-time equipment service stopped');
  }

  /// SAFE wrapper to prevent overlapping executions
  Future<void> _safeUpdateAll() async {
    if (_isUpdating) return;
    _isUpdating = true;

    try {
      await _updateAllEquipmentStatus();
    } finally {
      _isUpdating = false;
    }
  }

  /// MAIN UPDATE LOGIC (UNCHANGED, JUST SAFER)
  Future<void> _updateAllEquipmentStatus() async {
    try {
      final now = DateTime.now();
      print('🔄 Updating equipment status...');

      final equipmentSnapshot = await _firestore.collection('equipment').get();

      for (final equipmentDoc in equipmentSnapshot.docs) {
        await _updateSingleEquipmentStatus(equipmentDoc.id, now);
      }

      print('✅ Equipment status updated (${equipmentSnapshot.docs.length})');
    } catch (e) {
      print('❌ Real-time update error: $e');
    }
  }

  Future<void> _updateSingleEquipmentStatus(
    String equipmentId,
    DateTime now,
  ) async {
    try {
      final bookingsSnapshot = await _firestore
          .collection('equipment_bookings')
          .where('equipmentId', isEqualTo: equipmentId)
          .where('isCancelled', isEqualTo: false)
          .get();

      int activeNowCount = 0;
      final List<Map<String, dynamic>> activeBookings = [];

      for (final bookingDoc in bookingsSnapshot.docs) {
        try {
          final data = bookingDoc.data();
          final date = (data['date'] as Timestamp).toDate();
          final startTime = data['startTime'] as String;
          final duration = data['duration'] as int? ?? 30;

          final parts = startTime.split(':');
          final start = DateTime(
            date.year,
            date.month,
            date.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );

          final end = start.add(Duration(minutes: duration));

          if (now.isAfter(start) && now.isBefore(end)) {
            activeNowCount++;
            activeBookings.add({
              'start': start,
              'end': end,
              'user': data['userEmail'],
            });
          }
        } catch (_) {}
      }

      final equipmentDoc =
          await _firestore.collection('equipment').doc(equipmentId).get();

      if (!equipmentDoc.exists) return;

      final equipmentData = equipmentDoc.data()!;
      final currentStatus = equipmentData['status'] ?? 'available';

      final String newStatus = activeNowCount == 0 ? 'available' : 'in_use';
      final bool isAvailable = activeNowCount == 0;

      if (currentStatus != newStatus ||
          equipmentData['isAvailable'] != isAvailable ||
          equipmentData['currentUsers'] != activeNowCount) {
        await _firestore.collection('equipment').doc(equipmentId).update({
          'status': newStatus,
          'isAvailable': isAvailable,
          'currentUsers': activeNowCount,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      _equipmentStatusCache[equipmentId] = {
        'status': newStatus,
        'isAvailable': isAvailable,
        'activeUsers': activeNowCount,
        'lastChecked': now,
        'activeBookings': activeBookings,
      };
    } catch (e) {
      print('❌ Equipment $equipmentId update error: $e');
    }
  }

  /// Throttled Firestore listener
  void _listenToBookingChanges() {
    _firestore
        .collection('equipment_bookings')
        .where('isCancelled', isEqualTo: false)
        .snapshots()
        .listen((_) {
      print('📅 Booking change detected');
      _safeUpdateAll();
    });
  }

  Map<String, dynamic>? getEquipmentStatus(String equipmentId) {
    return _equipmentStatusCache[equipmentId];
  }

  Future<void> forceUpdateAllEquipment() async {
    await _safeUpdateAll();
  }
}
