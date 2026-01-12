// lib/services/booking_service.dart - PRODUCTION OPTIMIZED VERSION
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/equipment_booking.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ OPTIONAL BUT RECOMMENDED: Helper wrapper for booking next available turn
  // 📌 Why this is better:
  // 1. Keeps UI intent clear ("reserve next turn" vs "create booking")
  // 2. Business logic remains centralized in createBooking()
  // 3. No code duplication
  // 4. Easier to test and maintain
  Future<String> reserveNextTurn({
    required String equipmentId,
    required String equipmentName,
    required String userId,
    required String userEmail,
    required DateTime startTime,
    int duration = 30,
  }) async {
    print('🎯 Reserving next turn for $equipmentName');
    print('   Start time: $startTime');
    print('   Duration: $duration minutes');

    final booking = EquipmentBooking(
      userId: userId,
      userEmail: userEmail,
      equipmentId: equipmentId,
      equipmentName: equipmentName,
      date: DateTime(
        startTime.year,
        startTime.month,
        startTime.day,
      ),
      startTime: TimeOfDay(
        hour: startTime.hour,
        minute: startTime.minute,
      ),
      duration: duration,
      createdAt: DateTime.now(),
    );

    return createBooking(booking);
  }

  // Create booking with proper user info AND update equipment status ONLY if booking is active now
  Future<String> createBooking(EquipmentBooking booking) async {
    try {
      print('\n📝 Creating booking...');
      print('   User: ${booking.userId} (${booking.userEmail})');
      print(
          '   Equipment: ${booking.equipmentName} (ID: ${booking.equipmentId})');
      print('   Date: ${booking.date}');
      print('   Time: ${booking.startTime}');
      print('   Duration: ${booking.duration} minutes');

      // ✅ SERVICE-LEVEL PROTECTION: Check for time slot conflicts
      final isAvailable = await _isEquipmentAvailable(
        booking.equipmentId,
        booking.date,
        booking.startTime,
        booking.duration,
      );

      if (!isAvailable) {
        throw Exception('Equipment already booked for this time slot');
      }

      // Start a batch write for atomic consistency
      final batch = _firestore.batch();

      // 1. Create booking document
      final bookingRef = _firestore.collection('equipment_bookings').doc();
      batch.set(bookingRef, booking.toFirestore());

      // 2. Determine if booking is active NOW (current time is within booking time)
      final now = DateTime.now();
      final bookingStart = DateTime(
        booking.date.year,
        booking.date.month,
        booking.date.day,
        booking.startTime.hour,
        booking.startTime.minute,
      );
      final bookingEnd = bookingStart.add(Duration(minutes: booking.duration));

      final isActiveNow = now.isAfter(bookingStart) && now.isBefore(bookingEnd);

      print('   Booking time: ${bookingStart} - ${bookingEnd}');
      print('   Current time: $now');
      print('   Is booking active now? $isActiveNow');

      // ✅ CRITICAL: Only update equipment status if booking is currently active
      // Future bookings do NOT affect current equipment availability
      if (isActiveNow) {
        final equipmentRef =
            _firestore.collection('equipment').doc(booking.equipmentId);

        // Get current equipment state
        final equipmentDoc = await equipmentRef.get();
        final currentUsers = equipmentDoc.data()?['currentUsers'] as int? ?? 0;
        final maxCapacity = equipmentDoc.data()?['maxCapacity'] as int? ?? 1;

        // Calculate new state
        int newUserCount = currentUsers + 1;
        String newStatus;
        bool newAvailability;

        if (newUserCount >= maxCapacity) {
          newStatus = 'fully_booked';
          newAvailability = false;
        } else {
          newStatus = 'in_use';
          newAvailability = false;
        }

        // Update equipment in batch
        batch.update(equipmentRef, {
          'status': newStatus,
          'isAvailable': newAvailability,
          'currentUsers': newUserCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('   Equipment status updated: $newStatus');
        print('   Current users: $newUserCount');
      } else {
        print('   Booking is for future time - equipment status unchanged');
      }

      // Commit the batch transaction
      await batch.commit();

      print('✅ Booking saved successfully!');
      print('   Booking ID: ${bookingRef.id}');

      return bookingRef.id;
    } catch (e) {
      print('❌ Error saving booking: $e');
      rethrow;
    }
  }

  // Cancel booking AND restore equipment status if applicable
  Future<void> cancelBooking(String bookingId) async {
    try {
      print('🗑️  Cancelling booking: $bookingId');

      // Get booking details first
      final bookingDoc = await _firestore
          .collection('equipment_bookings')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        throw Exception('Booking not found');
      }

      final booking = EquipmentBooking.fromFirestore(bookingDoc);

      // Start batch write for consistency
      final batch = _firestore.batch();

      // 1. Mark booking as cancelled
      final bookingRef =
          _firestore.collection('equipment_bookings').doc(bookingId);
      batch.update(bookingRef, {
        'isCancelled': true,
        'cancelledAt': FieldValue.serverTimestamp(),
      });

      // 2. Check if booking was active and restore equipment status
      final now = DateTime.now();
      final bookingStart = DateTime(
        booking.date.year,
        booking.date.month,
        booking.date.day,
        booking.startTime.hour,
        booking.startTime.minute,
      );
      final bookingEnd = bookingStart.add(Duration(minutes: booking.duration));

      final wasActive = now.isAfter(bookingStart) && now.isBefore(bookingEnd);

      if (wasActive) {
        final equipmentRef =
            _firestore.collection('equipment').doc(booking.equipmentId);

        // Get current equipment state
        final equipmentDoc = await equipmentRef.get();
        final currentUsers = equipmentDoc.data()?['currentUsers'] as int? ?? 1;
        final maxCapacity = equipmentDoc.data()?['maxCapacity'] as int? ?? 1;

        // ✅ SAFE: Clamp user count to prevent negative values
        int newUserCount = (currentUsers - 1).clamp(0, maxCapacity);
        String newStatus;
        bool newAvailability;

        // Determine new status based on remaining users
        if (newUserCount <= 0) {
          newStatus = 'available';
          newAvailability = true;
        } else if (newUserCount >= maxCapacity) {
          newStatus = 'fully_booked';
          newAvailability = false;
        } else {
          newStatus = 'in_use';
          newAvailability = false;
        }

        batch.update(equipmentRef, {
          'currentUsers': newUserCount,
          'status': newStatus,
          'isAvailable': newAvailability,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print('   Equipment status updated: $newStatus');
        print('   Current users: $newUserCount');
      }

      await batch.commit();

      print('✅ Booking cancelled successfully');
    } catch (e) {
      print('❌ Error cancelling booking: $e');
      rethrow;
    }
  }

  // ✅ CORE LOGIC: Check for time slot conflicts
  Future<bool> _isEquipmentAvailable(
    String equipmentId,
    DateTime date,
    TimeOfDay startTime,
    int duration,
  ) async {
    try {
      final requestedStart = DateTime(
        date.year,
        date.month,
        date.day,
        startTime.hour,
        startTime.minute,
      );

      final requestedEnd = requestedStart.add(Duration(minutes: duration));

      // Get all non-cancelled bookings for this equipment
      final snapshot = await _firestore
          .collection('equipment_bookings')
          .where('equipmentId', isEqualTo: equipmentId)
          .where('isCancelled', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        final booking = EquipmentBooking.fromFirestore(doc);

        // Check if booking is on the same date
        if (booking.date.year == date.year &&
            booking.date.month == date.month &&
            booking.date.day == date.day) {
          final bookingStart = DateTime(
            booking.date.year,
            booking.date.month,
            booking.date.day,
            booking.startTime.hour,
            booking.startTime.minute,
          );

          final bookingEnd =
              bookingStart.add(Duration(minutes: booking.duration));

          // ✅ Check for time overlap
          if (requestedStart.isBefore(bookingEnd) &&
              requestedEnd.isAfter(bookingStart)) {
            print('   ❌ Time slot conflict detected:');
            print('      Requested: $requestedStart - $requestedEnd');
            print('      Booked: $bookingStart - $bookingEnd');
            return false; // Conflict found
          }
        }
      }

      print('   ✅ No time slot conflicts found');
      return true; // No conflicts
    } catch (e) {
      print('❌ Error checking availability: $e');
      return false; // Fail-safe: assume not available on error
    }
  }

  // ✅ 24-HOUR GYM: Get next available slot with no time restrictions
  Future<DateTime?> getNextAvailableSlot({
    required String equipmentId,
    required DateTime date,
    required int duration,
  }) async {
    try {
      print('\n🔍 Calculating next available slot...');
      print('   Equipment ID: $equipmentId');
      print('   Date: $date');
      print('   Duration: $duration minutes');

      // Get existing bookings for the date
      final bookings = await getBookingsForEquipmentAndDate(equipmentId, date);

      // Sort bookings chronologically
      bookings.sort((a, b) => a.bookingDateTime.compareTo(b.bookingDateTime));

      final now = DateTime.now();
      DateTime currentCheck;

      // If checking today, start from current time + buffer
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        currentCheck = now.add(const Duration(minutes: 5));
        print('   Starting from current time + 5 minutes: $currentCheck');
      } else {
        // For future dates, start from early morning
        currentCheck = DateTime(date.year, date.month, date.day, 6, 0);
        print('   Starting from beginning of day: $currentCheck');
      }

      // ✅ 24-HOUR GYM: Check for available slots within next 24 hours
      final maxCheckTime = currentCheck.add(const Duration(hours: 24));

      print('   Gym is open 24 hours, checking up to: $maxCheckTime');

      // Search for first available slot
      while (currentCheck.isBefore(maxCheckTime)) {
        final slotEnd = currentCheck.add(Duration(minutes: duration));

        // Check for conflicts with existing bookings
        bool hasConflict = false;
        for (final booking in bookings) {
          if (currentCheck.isBefore(booking.bookingEndTime) &&
              slotEnd.isAfter(booking.bookingDateTime)) {
            // Conflict found, move to end of this booking
            currentCheck = booking.bookingEndTime;
            hasConflict = true;
            print('   Conflict found, moving to: $currentCheck');
            break;
          }
        }

        // If no conflict, this slot is available
        if (!hasConflict) {
          print('   ✅ Found available slot: $currentCheck');
          return currentCheck;
        }
      }

      // No available slots found within 24 hours
      print('   ❌ No available slots found within next 24 hours');
      return null;
    } catch (e) {
      print('❌ Error calculating next available slot: $e');
      return null;
    }
  }

  // Real-time stream of user bookings
  Stream<List<EquipmentBooking>> getUserBookingsStream(String userId) {
    print('📡 Setting up bookings stream for user: $userId');

    try {
      return _firestore
          .collection('equipment_bookings')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .handleError((error) {
        print('❌ Error in bookings stream: $error');

        if (error.toString().contains('index') ||
            error.toString().contains('FAILED_PRECONDITION')) {
          print('⚠️  INDEX ERROR: Firestore needs a composite index');
        }
      }).map((snapshot) {
        print('📊 Bookings stream update: ${snapshot.docs.length} documents');

        final bookings = snapshot.docs
            .map((doc) {
              try {
                return EquipmentBooking.fromFirestore(doc);
              } catch (e) {
                print('❌ Error parsing document ${doc.id}: $e');
                return null;
              }
            })
            .where((booking) => booking != null)
            .cast<EquipmentBooking>()
            .toList();

        // Sort locally for consistent ordering
        bookings.sort((a, b) {
          if (a.date.isBefore(b.date)) return -1;
          if (a.date.isAfter(b.date)) return 1;

          final aMinutes = a.startTime.hour * 60 + a.startTime.minute;
          final bMinutes = b.startTime.hour * 60 + b.startTime.minute;
          return aMinutes.compareTo(bMinutes);
        });

        print('✅ Parsed and sorted ${bookings.length} bookings');
        return bookings;
      });
    } catch (e) {
      print('❌ Error creating stream: $e');
      return Stream.value([]);
    }
  }

  // Get booking statistics for dashboard
  Future<Map<String, int>> getUserBookingStats(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('equipment_bookings')
          .where('userId', isEqualTo: userId)
          .get();

      int active = 0;
      int upcoming = 0;
      int completed = 0;
      int cancelled = 0;

      for (final doc in snapshot.docs) {
        final booking = EquipmentBooking.fromFirestore(doc);

        if (booking.isCancelled) {
          cancelled++;
        } else if (booking.isCompleted) {
          completed++;
        } else if (booking.isUpcoming) {
          upcoming++;
        } else if (booking.isActive) {
          active++;
        }
      }

      return {
        'active': active,
        'upcoming': upcoming,
        'completed': completed,
        'cancelled': cancelled,
      };
    } catch (e) {
      print('❌ Error getting booking stats: $e');
      return {'active': 0, 'upcoming': 0, 'completed': 0, 'cancelled': 0};
    }
  }

  // Get single booking by ID
  Future<EquipmentBooking?> getBookingById(String bookingId) async {
    try {
      final doc = await _firestore
          .collection('equipment_bookings')
          .doc(bookingId)
          .get();

      if (doc.exists) {
        return EquipmentBooking.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('❌ Error getting booking: $e');
      return null;
    }
  }

  // Complete an expired booking and restore equipment
  Future<void> _completeExpiredBooking(EquipmentBooking booking) async {
    try {
      print('🔄 Completing expired booking: ${booking.id}');
      print('   Equipment: ${booking.equipmentName}');
      print('   Ended at: ${booking.formattedEndTime}');

      final equipmentRef =
          _firestore.collection('equipment').doc(booking.equipmentId);

      // Get current equipment state
      final equipmentDoc = await equipmentRef.get();
      final currentUsers = equipmentDoc.data()?['currentUsers'] as int? ?? 1;
      final maxCapacity = equipmentDoc.data()?['maxCapacity'] as int? ?? 1;

      // ✅ SAFE: Clamp to prevent negative values
      int newUserCount = (currentUsers - 1).clamp(0, maxCapacity);
      String newStatus;
      bool newAvailability;

      if (newUserCount <= 0) {
        newStatus = 'available';
        newAvailability = true;
      } else if (newUserCount >= maxCapacity) {
        newStatus = 'fully_booked';
        newAvailability = false;
      } else {
        newStatus = 'in_use';
        newAvailability = false;
      }

      // Update equipment status
      await equipmentRef.update({
        'status': newStatus,
        'isAvailable': newAvailability,
        'currentUsers': newUserCount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Equipment ${booking.equipmentName} status updated: $newStatus');
      print('   Current users: $newUserCount');
    } catch (e) {
      print('❌ Error completing expired booking: $e');
    }
  }

  // ✅ AUTO-CLEANUP: Check and process expired bookings
  Future<void> checkAndUpdateExpiredBookings() async {
    try {
      print('🕒 Checking for expired bookings...');

      final now = DateTime.now();

      // Get all active (non-cancelled) bookings
      final snapshot = await _firestore
          .collection('equipment_bookings')
          .where('isCancelled', isEqualTo: false)
          .get();

      int expiredCount = 0;

      for (final doc in snapshot.docs) {
        try {
          final booking = EquipmentBooking.fromFirestore(doc);
          final bookingEnd = booking.bookingEndTime;

          // Check if booking has ended
          if (now.isAfter(bookingEnd)) {
            expiredCount++;
            print(
                '📅 Booking expired: ${booking.equipmentName} ended at ${booking.formattedEndTime}');
            await _completeExpiredBooking(booking);
          }
        } catch (e) {
          print('❌ Error processing booking ${doc.id}: $e');
        }
      }

      print(
          '✅ Checked ${snapshot.docs.length} bookings, $expiredCount expired');
    } catch (e) {
      print('❌ Error checking expired bookings: $e');
    }
  }

  // Get bookings for specific equipment on a specific date
  Future<List<EquipmentBooking>> getBookingsForEquipmentAndDate(
    String equipmentId,
    DateTime date,
  ) async {
    try {
      print(
          '📅 Getting bookings for equipment $equipmentId on ${date.toString()}');

      final snapshot = await _firestore
          .collection('equipment_bookings')
          .where('equipmentId', isEqualTo: equipmentId)
          .where('isCancelled', isEqualTo: false)
          .get();

      // Filter locally by date for query efficiency
      final bookings = snapshot.docs
          .map((doc) => EquipmentBooking.fromFirestore(doc))
          .where((booking) =>
              booking.date.year == date.year &&
              booking.date.month == date.month &&
              booking.date.day == date.day)
          .toList();

      print('✅ Found ${bookings.length} bookings for selected date');
      return bookings;
    } catch (e) {
      print('❌ Error getting bookings: $e');
      return [];
    }
  }

  // Initialize booking cleanup service
  Future<void> initializeBookingCleanup() async {
    try {
      // Check for expired bookings on app start
      await checkAndUpdateExpiredBookings();

      // Optional: Uncomment to set up periodic checks
      // Timer.periodic(Duration(minutes: 5), (_) async {
      //   await checkAndUpdateExpiredBookings();
      // });

      print('✅ Booking cleanup service initialized');
    } catch (e) {
      print('❌ Error initializing booking cleanup: $e');
    }
  }

  // Get upcoming bookings for dashboard display
  Future<List<EquipmentBooking>> getUpcomingBookings(String userId) async {
    try {
      final now = DateTime.now();

      final snapshot = await _firestore
          .collection('equipment_bookings')
          .where('userId', isEqualTo: userId)
          .where('isCancelled', isEqualTo: false)
          .get();

      final upcomingBookings = snapshot.docs
          .map((doc) => EquipmentBooking.fromFirestore(doc))
          .where((booking) => booking.isUpcoming)
          .toList();

      // Sort by date and time
      upcomingBookings.sort((a, b) {
        final aStart = DateTime(
          a.date.year,
          a.date.month,
          a.date.day,
          a.startTime.hour,
          a.startTime.minute,
        );
        final bStart = DateTime(
          b.date.year,
          b.date.month,
          b.date.day,
          b.startTime.hour,
          b.startTime.minute,
        );
        return aStart.compareTo(bStart);
      });

      return upcomingBookings;
    } catch (e) {
      print('❌ Error getting upcoming bookings: $e');
      return [];
    }
  }
}
