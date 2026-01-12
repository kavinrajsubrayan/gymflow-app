// lib/models/equipment.dart - COMPLETE UPDATED VERSION
import 'package:flutter/material.dart';

class Equipment {
  String? id;
  String name;
  String category;
  String description;
  int maxDuration;
  String status; // 'available', 'in_use', 'fully_booked'
  bool isAvailable;
  int currentUsers;
  int maxCapacity;

  Equipment({
    this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.maxDuration,
    this.status = 'available',
    this.isAvailable = true,
    this.currentUsers = 0,
    this.maxCapacity = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'description': description,
      'maxDuration': maxDuration,
      'status': status,
      'isAvailable': isAvailable,
      'currentUsers': currentUsers,
      'maxCapacity': maxCapacity,
    };
  }

  factory Equipment.fromMap(String id, Map<String, dynamic> map) {
    // Handle missing fields by providing defaults
    return Equipment(
      id: id,
      name: map['name']?.toString() ?? 'Unknown Equipment',
      category: map['category']?.toString() ?? 'General',
      description: map['description']?.toString() ?? 'No description available',
      maxDuration: (map['maxDuration'] as num?)?.toInt() ?? 30,
      status: map['status']?.toString() ?? 'available',
      isAvailable: map['isAvailable'] as bool? ??
          (map['status']?.toString() == 'available'),
      currentUsers: (map['currentUsers'] as num?)?.toInt() ?? 0,
      maxCapacity: (map['maxCapacity'] as num?)?.toInt() ?? 1,
    );
  }

  // Helper methods to check status - FIXED VERSION
  bool get isAvailableNow => status == 'available' && isAvailable;
  bool get isInUse => status == 'in_use';
  bool get isFullyBooked => status == 'fully_booked';

  String get statusText {
    switch (status) {
      case 'available':
        return 'Available Now';
      case 'in_use':
        return 'Currently in Use';
      case 'fully_booked':
        return 'Fully Booked';
      default:
        return 'Available';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'in_use':
        return Colors.orange;
      case 'fully_booked':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  Color get statusBackgroundColor {
    switch (status) {
      case 'available':
        return Colors.green.withOpacity(0.1);
      case 'in_use':
        return Colors.orange.withOpacity(0.1);
      case 'fully_booked':
        return Colors.red.withOpacity(0.1);
      default:
        return Colors.green.withOpacity(0.1);
    }
  }

  // Get capacity status
  String get capacityText {
    return '$currentUsers/$maxCapacity users';
  }

  // Check if equipment can be booked
  bool get canBook {
    return isAvailableNow && currentUsers < maxCapacity;
  }
}
