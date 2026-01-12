// lib/widgets/equipment_status_widget.dart - COMPLETE UPDATED VERSION
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/equipment.dart';
import '../services/equipment_service.dart';
import '../screens/book_equipment_screen.dart';

class EquipmentStatusWidget extends StatefulWidget {
  final String? category;
  final bool showQuickBook;

  const EquipmentStatusWidget({
    super.key,
    this.category,
    this.showQuickBook = false,
  });

  @override
  State<EquipmentStatusWidget> createState() => _EquipmentStatusWidgetState();
}

class _EquipmentStatusWidgetState extends State<EquipmentStatusWidget> {
  final EquipmentService _equipmentService = EquipmentService();
  late Stream<List<Equipment>> _equipmentStream;

  @override
  void initState() {
    super.initState();
    _equipmentStream = _getAvailableEquipmentStream();
  }

  // NEW: Stream that filters ONLY available equipment
  Stream<List<Equipment>> _getAvailableEquipmentStream() {
    return _equipmentService.getEquipmentStream().map((allEquipment) {
      // Filter only available equipment
      final availableEquipment =
          allEquipment.where((equipment) => equipment.isAvailableNow).toList();

      // Sort by name or category
      availableEquipment.sort((a, b) => a.name.compareTo(b.name));

      // Limit to 5 items max
      return availableEquipment.take(5).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Equipment>>(
      stream: _equipmentStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildError(snapshot.error);
        }

        final availableEquipment = snapshot.data!;

        if (availableEquipment.isEmpty) {
          return _buildNoAvailableEquipment();
        }

        return _buildAvailableEquipmentList(availableEquipment);
      },
    );
  }

  Widget _buildLoading() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          CircularProgressIndicator(strokeWidth: 2),
          SizedBox(width: 12),
          Text(
            'Loading available equipment...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object? error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 16),
              SizedBox(width: 8),
              Text(
                'Equipment Status Unavailable',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Could not load equipment data',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAvailableEquipment() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Text(
                'No Equipment Available Now',
                style: TextStyle(
                    color: Colors.orange, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'All equipment is currently in use or booked',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      BookEquipmentScreen(selectedCategory: 'All'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 40),
            ),
            child: const Text('Book for Later'),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableEquipmentList(List<Equipment> equipmentList) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🏋️ Available Equipment Now',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${equipmentList.length} available',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              // Live indicator
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                  ),
                  const Text(
                    'Live',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Available equipment list
          ...equipmentList.map((equipment) {
            return _buildAvailableEquipmentItem(equipment);
          }).toList(),

          // "Book Now" button
          if (widget.showQuickBook)
            Container(
              margin: const EdgeInsets.only(top: 16),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          BookEquipmentScreen(selectedCategory: 'All'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: const Text('Book Available Equipment'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvailableEquipmentItem(Equipment equipment) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                BookEquipmentScreen(selectedCategory: equipment.category),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 12),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green,
              ),
            ),

            // Equipment details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    equipment.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(equipment.category)
                              .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          equipment.category,
                          style: TextStyle(
                            color: _getCategoryColor(equipment.category),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.timer,
                        color: Colors.grey[400],
                        size: 12,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Max ${equipment.maxDuration} min',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Quick book icon
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookEquipmentScreen(
                        selectedCategory: equipment.category),
                  ),
                );
              },
              icon: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.green,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Cardio':
        return Colors.blue;
      case 'Free Weights':
        return Colors.orange;
      case 'Functional':
        return Colors.purple;
      case 'Strength':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
