// lib/screens/book_equipment_screen.dart - FIXED VERSION
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Added for kReleaseMode
import 'package:cloud_firestore/cloud_firestore.dart';
import 'equipment_booking_screen.dart';
import '../models/equipment.dart';
import '../services/equipment_service.dart';
import 'firestore_debug_screen.dart';

class BookEquipmentScreen extends StatefulWidget {
  final String selectedCategory;
  const BookEquipmentScreen({super.key, required this.selectedCategory});

  @override
  State<BookEquipmentScreen> createState() => _BookEquipmentScreenState();
}

class _BookEquipmentScreenState extends State<BookEquipmentScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = [
    'All',
    'Cardio',
    'Free Weights',
    'Functional',
    'Strength'
  ];

  final EquipmentService _equipmentService = EquipmentService();
  late Stream<List<Equipment>> _equipmentStream;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.selectedCategory;

    if (!kReleaseMode) {
      print('🚀 INITIALIZING BookEquipmentScreen');
      print('Selected category: $_selectedFilter');
    }

    // Initialize the stream
    _equipmentStream = _getEquipmentStream();

    // Test connection in background (don't block UI)
    _testConnectionInBackground();
  }

  void _testConnectionInBackground() async {
    try {
      await FirebaseFirestore.instance
          .collection('equipment')
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      if (!kReleaseMode) {
        print('✅ Background connection test successful');
      }
    } catch (e) {
      if (!kReleaseMode) {
        print('⚠️ Background connection test failed: $e');
      }
    }
  }

  Stream<List<Equipment>> _getEquipmentStream() {
    if (!kReleaseMode) {
      print('🔄 Getting equipment stream for category: $_selectedFilter');
    }

    if (_selectedFilter == 'All') {
      return _equipmentService.getEquipmentStream();
    }

    return _equipmentService.getEquipmentByCategory(_selectedFilter);
  }

  void _updateFilter(String filter) {
    if (!kReleaseMode) {
      print('🎯 Changing filter to: $filter');
    }
    setState(() {
      _selectedFilter = filter;
      _equipmentStream = _getEquipmentStream();
    });
  }

  String _getCategoryIcon(String category) {
    switch (category) {
      case 'Cardio':
        return '🏃‍♂️';
      case 'Free Weights':
        return '🏋️‍♂️';
      case 'Functional':
        return '⚡';
      case 'Strength':
        return '💪';
      default:
        return '🏋️‍♂️';
    }
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
        return Colors.blue;
    }
  }

  void _showDebugScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FirestoreDebugScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Book ${_selectedFilter == 'All' ? 'Equipment' : _selectedFilter}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Only show debug button in development mode
          if (!kReleaseMode)
            IconButton(
              icon: const Icon(Icons.bug_report, color: Colors.white),
              onPressed: _showDebugScreen,
              tooltip: 'Debug Firestore',
            ),
        ],
      ),
      body: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Header with Stats - Now uses StreamBuilder properly
        StreamBuilder<List<Equipment>>(
          stream: _equipmentStream,
          builder: (context, snapshot) {
            // Show loading state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildHeaderLoading();
            }

            // Show error state
            if (snapshot.hasError) {
              return _buildHeaderError(snapshot.error.toString());
            }

            // Show data
            final equipmentList = snapshot.data ?? [];
            final availableCount =
                equipmentList.where((e) => e.isAvailableNow).length;
            final inUseCount = equipmentList.where((e) => e.isInUse).length;
            final bookedCount =
                equipmentList.where((e) => e.isFullyBooked).length;

            return _buildHeader(
                equipmentList.length, availableCount, inUseCount, bookedCount);
          },
        ),

        // Filter Chips
        _buildFilterChips(),

        // Equipment List
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<List<Equipment>>(
              stream: _equipmentStream,
              builder: (context, snapshot) {
                // Loading state
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                // Error state
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                // Data loaded
                final equipmentList = snapshot.data ?? [];

                if (equipmentList.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildEquipmentList(equipmentList);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderLoading() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getCategoryColor(_selectedFilter).withOpacity(0.3),
            Colors.black,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedFilter} Equipment',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Loading equipment data...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderError(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red.withOpacity(0.3),
            Colors.black,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedFilter} Equipment',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Connection error - ${kReleaseMode ? 'Please try again later' : 'Tap debug button above'}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(int total, int available, int inUse, int booked) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getCategoryColor(_selectedFilter).withOpacity(0.3),
            Colors.black,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedFilter} Equipment',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$available available • $inUse in use • $booked booked',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Live Status',
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
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        height: 50,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: _filters.map((filter) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(
                  filter,
                  style: TextStyle(
                    color:
                        _selectedFilter == filter ? Colors.white : Colors.grey,
                    fontWeight: _selectedFilter == filter
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                selected: _selectedFilter == filter,
                onSelected: (selected) {
                  _updateFilter(filter);
                },
                backgroundColor: Colors.grey[900],
                selectedColor: _getCategoryColor(filter),
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              _getCategoryColor(_selectedFilter),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Loading equipment...',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    if (!kReleaseMode) {
      print('❌ Error loading equipment: $error');
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 20),
            const Text(
              'Connection Failed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red),
              ),
              child: Column(
                children: [
                  Text(
                    kReleaseMode ? 'Unable to load equipment' : error,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Possible issues:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• No internet connection\n• Firebase not configured\n• Firestore security rules blocking access\n• Equipment collection empty',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _equipmentStream = _getEquipmentStream();
                    });
                  },
                  child: const Text('Retry Connection'),
                ),
                const SizedBox(width: 16),
                // Only show debug button in development mode
                if (!kReleaseMode)
                  ElevatedButton(
                    onPressed: _showDebugScreen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Debug Tool'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            color: Colors.grey[600],
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'No equipment found',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Category "$_selectedFilter" has no equipment',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _equipmentStream = _getEquipmentStream();
              });
            },
            child: const Text('Refresh'),
          ),
          const SizedBox(height: 10),
          // Only show debug button in development mode
          if (!kReleaseMode)
            TextButton(
              onPressed: _showDebugScreen,
              child: const Text('Open Debug Tool'),
            ),
        ],
      ),
    );
  }

  Widget _buildEquipmentList(List<Equipment> equipmentList) {
    if (!kReleaseMode) {
      print('✅ Loaded ${equipmentList.length} equipment items');
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: equipmentList.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Header row stays inside the scroll
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Equipment (${equipmentList.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Live',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final equipment = equipmentList[index - 1];
        return _buildEquipmentCard(equipment);
      },
    );
  }

  Widget _buildEquipmentCard(Equipment equipment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Equipment Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: equipment.statusBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        _getCategoryColor(equipment.category).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getCategoryColor(equipment.category)
                          .withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    _getCategoryIcon(equipment.category),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipment.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.timer, color: Colors.grey[400], size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Max ${equipment.maxDuration} min',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.people, color: Colors.grey[400], size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${equipment.currentUsers}/${equipment.maxCapacity}',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: equipment.statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: equipment.statusColor),
                  ),
                  child: Text(
                    equipment.statusText,
                    style: TextStyle(
                      color: equipment.statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Equipment Description and Action
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipment.description,
                        style: TextStyle(
                          color: Colors.grey[300],
                          fontSize: 14,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildFeatureChip(
                              'Heart Rate Monitor', Icons.monitor_heart),
                          _buildFeatureChip(
                              'Digital Display', Icons.display_settings),
                          if (equipment.maxCapacity > 1)
                            _buildFeatureChip('Multi-user', Icons.people),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _buildBookButton(equipment),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.blue, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookButton(Equipment equipment) {
    // ❌ Fully booked = cannot book at all
    if (equipment.isFullyBooked) {
      return SizedBox(
        width: 120,
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey,
            side: const BorderSide(color: Colors.grey),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text(
            'Fully Booked',
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // ✅ Available OR In Use → both can go to booking screen
    return SizedBox(
      width: 160, // ✅ Increased from 120 to 160
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  EquipmentBookingScreen(equipment: equipment),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: equipment.isInUse ? Colors.orange : Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.book_online, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                equipment.isInUse ? 'Book Later' : 'Book Next Available',
                style: const TextStyle(fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
