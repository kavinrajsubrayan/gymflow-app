// lib/utils/gym_occupancy_service.dart - COMPLETE UPDATED VERSION
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/equipment_booking.dart';

// Enhanced Gym Session Model with Duration Tracking
class GymSession {
  final String? id;
  final String userId;
  final String userName;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final bool isActive;
  int workoutDurationSeconds; // Track workout duration
  DateTime lastUpdateTime; // Track when duration was last updated

  GymSession({
    this.id,
    required this.userId,
    required this.userName,
    required this.checkInTime,
    this.checkOutTime,
    required this.isActive,
    this.workoutDurationSeconds = 0,
    required this.lastUpdateTime,
  });

  // Calculate current duration including time since last update
  int getCurrentDuration() {
    if (!isActive) return workoutDurationSeconds;

    final now = DateTime.now();
    final secondsSinceLastUpdate = now.difference(lastUpdateTime).inSeconds;
    return workoutDurationSeconds + secondsSinceLastUpdate;
  }

  // Update duration manually
  void updateDuration() {
    if (isActive) {
      final now = DateTime.now();
      final secondsSinceLastUpdate = now.difference(lastUpdateTime).inSeconds;
      workoutDurationSeconds += secondsSinceLastUpdate;
      lastUpdateTime = now;
    }
  }
}

// Enhanced Gym Occupancy Service with Persistent Workout Timer
class GymOccupancyService {
  static int _currentOccupancy = 0;
  static final Map<String, GymSession> _activeSessions = {};
  static final StreamController<int> _occupancyController =
      StreamController<int>.broadcast();

  // Check in user
  Future<void> checkIn(String userId, String userName) async {
    try {
      // Check if user already has active session
      if (_activeSessions.containsKey(userId)) {
        // User already has active session - resume it
        print('🔄 Resuming existing workout session for $userName');
        return;
      }

      final session = GymSession(
        userId: userId,
        userName: userName,
        checkInTime: DateTime.now(),
        isActive: true,
        workoutDurationSeconds: 0,
        lastUpdateTime: DateTime.now(),
      );

      _activeSessions[userId] = session;
      _currentOccupancy++;

      // Notify listeners
      _occupancyController.add(_currentOccupancy);

      print(
          '✅ User $userName checked in. Current occupancy: $_currentOccupancy');
    } catch (e) {
      print('❌ Error checking in: $e');
      throw e;
    }
  }

  // Check out user
  Future<void> checkOut(String userId) async {
    try {
      if (!_activeSessions.containsKey(userId)) {
        throw Exception('No active session found!');
      }

      final session = _activeSessions[userId]!;
      // Update duration before checkout
      session.updateDuration();

      _activeSessions.remove(userId);
      _currentOccupancy = _currentOccupancy > 0 ? _currentOccupancy - 1 : 0;

      // Notify listeners
      _occupancyController.add(_currentOccupancy);

      print(
          '✅ User ${session.userName} checked out. Workout duration: ${session.workoutDurationSeconds} seconds. Current occupancy: $_currentOccupancy');
    } catch (e) {
      print('❌ Error checking out: $e');
      throw e;
    }
  }

  // Get active session for user
  Future<GymSession?> getActiveUserSession(String userId) async {
    try {
      return _activeSessions[userId];
    } catch (e) {
      print('❌ Error getting active session: $e');
      return null;
    }
  }

  // Get current workout duration for user (calculates real-time duration)
  Future<int> getWorkoutDuration(String userId) async {
    try {
      final session = _activeSessions[userId];
      if (session != null && session.isActive) {
        return session.getCurrentDuration();
      }
      return session?.workoutDurationSeconds ?? 0;
    } catch (e) {
      print('❌ Error getting workout duration: $e');
      return 0;
    }
  }

  // Update all active sessions (call this periodically)
  void updateAllActiveSessions() {
    _activeSessions.forEach((userId, session) {
      if (session.isActive) {
        session.updateDuration();
      }
    });
  }

  // Get current occupancy count
  Future<int> getCurrentOccupancy() async {
    return _currentOccupancy;
  }

  // Real-time occupancy listener
  Stream<int> getOccupancyStream() {
    return _occupancyController.stream;
  }

  // Clean up
  static void dispose() {
    _occupancyController.close();
  }
}

// Equipment Status Service
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

  // NEW METHOD: Sync equipment status with actual bookings
  Future<void> syncEquipmentWithBookings() async {
    try {
      print('🔄 Syncing equipment with active bookings...');

      final now = DateTime.now();

      // Get all equipment
      final equipmentSnapshot = await _firestore.collection('equipment').get();

      for (var doc in equipmentSnapshot.docs) {
        final equipmentId = doc.id;
        final data = doc.data();

        // Get all non-cancelled bookings for this equipment
        final bookingsSnapshot = await _firestore
            .collection('equipment_bookings')
            .where('equipmentId', isEqualTo: equipmentId)
            .where('isCancelled', isEqualTo: false)
            .get();

        int activeBookingsCount = 0;

        // Count active bookings (bookings that are happening now)
        for (var bookingDoc in bookingsSnapshot.docs) {
          try {
            final booking = EquipmentBooking.fromFirestore(bookingDoc);
            final bookingStart = booking.bookingDateTime;
            final bookingEnd = booking.bookingEndTime;

            // Check if booking is currently active
            if (now.isAfter(bookingStart) && now.isBefore(bookingEnd)) {
              activeBookingsCount++;
            }
          } catch (e) {
            print('❌ Error parsing booking: $e');
          }
        }

        final maxCapacity = data['maxCapacity'] as int? ?? 1;
        String correctStatus;
        bool correctAvailability;

        if (activeBookingsCount <= 0) {
          correctStatus = 'available';
          correctAvailability = true;
        } else if (activeBookingsCount >= maxCapacity) {
          correctStatus = 'fully_booked';
          correctAvailability = false;
        } else {
          correctStatus = 'in_use';
          correctAvailability = false;
        }

        // Update if status is incorrect
        if (data['status'] != correctStatus ||
            data['isAvailable'] != correctAvailability ||
            data['currentUsers'] != activeBookingsCount) {
          await _firestore.collection('equipment').doc(equipmentId).update({
            'status': correctStatus,
            'isAvailable': correctAvailability,
            'currentUsers': activeBookingsCount,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          print('✅ Fixed equipment ${data['name']}:');
          print(
              '   • Old: ${data['status']} (available: ${data['isAvailable']})');
          print('   • New: $correctStatus (available: $correctAvailability)');
          print('   • Active bookings: $activeBookingsCount');
        }
      }

      print('✅ Equipment-bookings sync completed');
    } catch (e) {
      print('❌ Error syncing equipment with bookings: $e');
    }
  }
}

// Motivation Quotes Service
class MotivationService {
  static final List<String> workoutStartQuotes = [
    "💪 Let's crush this workout! The pain you feel today will be the strength you feel tomorrow!",
    "🔥 Time to unleash the beast! Remember why you started!",
    "🚀 Great things never come from comfort zones! Let's get uncomfortable!",
    "🌟 Believe in yourself and all that you are! This is your time to shine!",
    "🏋️‍♂️ The only bad workout is the one that didn't happen! Let's make this count!",
    "⚡ Don't stop when you're tired. Stop when you're done! You've got this!",
    "🎯 Success isn't always about greatness. It's about consistency! Let's go!",
    "💥 Your body can stand almost anything. It's your mind you have to convince!"
  ];

  static final List<String> workoutEndQuotes = [
    "🎉 Amazing work! You're one step closer to your goals!",
    "🌟 You showed up and gave it your all! That's what champions do!",
    "💪 The hardest part is over! Be proud of what you accomplished today!",
    "🔥 Consistency beats perfection! Great job completing your workout!",
    "🚀 Every rep counts! You're building a better version of yourself!",
    "🌈 Remember: sweat is just fat crying! Great job today!",
    "🏆 You didn't just work out today - you invested in yourself!",
    "✨ The only workout you regret is the one you didn't do! Proud of you!"
  ];

  static String getRandomStartQuote() {
    final random =
        DateTime.now().millisecondsSinceEpoch % workoutStartQuotes.length;
    return workoutStartQuotes[random.toInt()];
  }

  static String getRandomEndQuote() {
    final random =
        DateTime.now().millisecondsSinceEpoch % workoutEndQuotes.length;
    return workoutEndQuotes[random.toInt()];
  }
}
