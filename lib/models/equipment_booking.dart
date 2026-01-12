// lib/models/equipment_booking.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // ADD THIS IMPORT

class EquipmentBooking {
  String? id;
  String userId;
  String userEmail;
  String equipmentId;
  String equipmentName;
  DateTime date;
  TimeOfDay startTime;
  int duration;
  bool isCancelled;
  DateTime createdAt;

  EquipmentBooking({
    this.id,
    required this.userId,
    required this.userEmail,
    required this.equipmentId,
    required this.equipmentName,
    required this.date,
    required this.startTime,
    required this.duration,
    this.isCancelled = false,
    required this.createdAt,
  });

  // For Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'equipmentId': equipmentId,
      'equipmentName': equipmentName,
      'date': Timestamp.fromDate(date),
      'startTime': '${startTime.hour}:${startTime.minute}',
      'duration': duration,
      'isCancelled': isCancelled,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // Parse from DocumentSnapshot
  factory EquipmentBooking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse date from Timestamp
    DateTime bookingDate = (data['date'] as Timestamp).toDate();

    // Parse time from string
    TimeOfDay bookingTime;
    if (data['startTime'] is String) {
      final timeParts = (data['startTime'] as String).split(':');
      bookingTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );
    } else {
      bookingTime = TimeOfDay.now();
    }

    // Parse createdAt from Timestamp
    DateTime createdAt = (data['createdAt'] as Timestamp).toDate();

    return EquipmentBooking(
      id: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      equipmentId: data['equipmentId'] ?? '',
      equipmentName: data['equipmentName'] ?? '',
      date: bookingDate,
      startTime: bookingTime,
      duration: data['duration'] ?? 30,
      isCancelled: data['isCancelled'] ?? false,
      createdAt: createdAt,
    );
  }

  // Helper methods for time
  DateTime get bookingDateTime {
    return DateTime(
      date.year,
      date.month,
      date.day,
      startTime.hour,
      startTime.minute,
    );
  }

  DateTime get bookingEndTime {
    return bookingDateTime.add(Duration(minutes: duration));
  }

  bool get isActive {
    final now = DateTime.now();
    return !isCancelled &&
        bookingDateTime.isBefore(now) &&
        bookingEndTime.isAfter(now);
  }

  bool get isUpcoming {
    final now = DateTime.now();
    return !isCancelled && bookingDateTime.isAfter(now);
  }

  bool get isCompleted {
    final now = DateTime.now();
    return !isCancelled && bookingEndTime.isBefore(now);
  }

  // Format date
  String get formattedDate {
    final formatter = DateFormat('EEE, MMM d, y');
    return formatter.format(date);
  }

  // Format time
  String get formattedStartTime {
    final period = startTime.hour >= 12 ? 'PM' : 'AM';
    final hour = startTime.hourOfPeriod;
    final minute = startTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String get formattedEndTime {
    final totalMinutes = startTime.hour * 60 + startTime.minute + duration;
    final hour = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;

    final endTime = TimeOfDay(hour: hour, minute: minute);
    final period = endTime.hour >= 12 ? 'PM' : 'AM';
    final endHour = endTime.hourOfPeriod;
    final endMinute = endTime.minute.toString().padLeft(2, '0');
    return '$endHour:$endMinute $period';
  }
}
