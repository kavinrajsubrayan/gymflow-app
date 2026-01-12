// lib/screens/my_bookings_screen.dart - COMPLETE FIXED VERSION
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/equipment_booking.dart';
import '../services/booking_service.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  int _selectedTab = 0; // 0: Active, 1: Upcoming, 2: Completed, 3: Cancelled
  final BookingService _bookingService = BookingService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  Map<String, int> _bookingStats = {
    'active': 0,
    'upcoming': 0,
    'completed': 0,
    'cancelled': 0,
  };
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  void _checkAuthentication() async {
    print('🔐 Checking authentication...');
    print('   User: ${_user?.email}');
    print('   User ID: ${_user?.uid}');

    if (_user == null || _user?.uid == null || _user!.uid.isEmpty) {
      print('❌ No user authenticated');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No user logged in. Please sign in again.';
        });
      }
      return;
    }

    _loadBookingStats();
    _testFirestoreConnection();
  }

  Future<void> _loadBookingStats() async {
    try {
      final stats = await _bookingService.getUserBookingStats(_user!.uid);
      if (mounted) {
        setState(() {
          _bookingStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading booking stats: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load booking statistics.';
        });
      }
    }
  }

  Future<void> _testFirestoreConnection() async {
    try {
      print('🔗 Testing Firestore connection...');

      // Test if we can read from equipment_bookings
      final snapshot = await _firestore
          .collection('equipment_bookings')
          .where('userId', isEqualTo: _user!.uid)
          .limit(1)
          .get();

      print('✅ Firestore connection successful');
      print('   Found ${snapshot.docs.length} booking(s)');
    } catch (e, stackTrace) {
      print('❌ Firestore connection failed: $e');
      print('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _errorMessage = 'Firestore connection error: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('My Bookings', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorState(_errorMessage);
    }

    if (_user == null) {
      return _buildNoUserState();
    }

    return Column(
      children: [
        // Stats Overview
        _buildStatsOverview(),

        // Tab Bar
        _buildTabBar(),

        // Bookings List
        Expanded(
          child: _buildBookingsList(),
        ),
      ],
    );
  }

  Widget _buildStatsOverview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Booking Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                  'Active', _bookingStats['active'] ?? 0, Colors.green),
              _buildStatItem(
                  'Upcoming', _bookingStats['upcoming'] ?? 0, Colors.blue),
              _buildStatItem(
                  'Completed', _bookingStats['completed'] ?? 0, Colors.grey),
              _buildStatItem(
                  'Cancelled', _bookingStats['cancelled'] ?? 0, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String title, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
            border: Border.all(color: color, width: 2),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabButton('Active', 0, Icons.access_time),
            const SizedBox(width: 8),
            _buildTabButton('Upcoming', 1, Icons.upcoming),
            const SizedBox(width: 8),
            _buildTabButton('Completed', 2, Icons.check_circle),
            const SizedBox(width: 8),
            _buildTabButton('Cancelled', 3, Icons.cancel),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int tabIndex, IconData icon) {
    final isSelected = _selectedTab == tabIndex;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = tabIndex;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : Colors.grey, size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoUserState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_off, color: Colors.grey, size: 64),
          const SizedBox(height: 16),
          const Text(
            'Please log in to view bookings',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsList() {
    print('\n🔍 Building bookings list for tab: $_selectedTab');
    print('   User ID: ${_user!.uid}');

    return StreamBuilder<List<EquipmentBooking>>(
      stream: _bookingService.getUserBookingsStream(_user!.uid),
      builder: (context, snapshot) {
        print('\n📊 Stream Snapshot Status:');
        print('   Connection State: ${snapshot.connectionState}');
        print('   Has Data: ${snapshot.hasData}');
        print('   Has Error: ${snapshot.hasError}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        if (snapshot.hasError) {
          print('❌ Stream Error: ${snapshot.error}');
          print('   Error Type: ${snapshot.error.runtimeType}');

          // Check for specific Firestore errors
          if (snapshot.error.toString().contains('PERMISSION_DENIED') ||
              snapshot.error.toString().contains('permission-denied')) {
            return _buildFirestoreErrorState('Firestore Permission Denied',
                'Please check Firestore security rules or contact administrator.');
          } else if (snapshot.error.toString().contains('UNAVAILABLE')) {
            return _buildFirestoreErrorState('Firestore Unavailable',
                'Please check your internet connection.');
          } else if (snapshot.error
                  .toString()
                  .contains('FAILED_PRECONDITION') ||
              snapshot.error.toString().contains('index')) {
            return _buildIndexErrorState();
          }

          return _buildErrorState(snapshot.error.toString());
        }

        final bookings = snapshot.data ?? [];
        print('   📦 Data received: ${bookings.length} total bookings');

        final filteredBookings = _filterBookings(bookings);
        print(
            '   🎯 Filtered bookings: ${filteredBookings.length} for tab $_selectedTab');

        if (filteredBookings.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredBookings.length,
          itemBuilder: (context, index) {
            return _buildBookingCard(filteredBookings[index]);
          },
        );
      },
    );
  }

  List<EquipmentBooking> _filterBookings(List<EquipmentBooking> bookings) {
    final now = DateTime.now();

    return bookings.where((booking) {
      switch (_selectedTab) {
        case 0: // Active
          return booking.isActive;
        case 1: // Upcoming
          return booking.isUpcoming;
        case 2: // Completed
          return booking.isCompleted;
        case 3: // Cancelled
          return booking.isCancelled;
        default:
          return false;
      }
    }).toList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'Loading bookings...',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Failed to load bookings',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                error,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = '';
                      _checkAuthentication();
                    });
                  },
                  child: const Text('Retry'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    _debugCheckBookings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Debug'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndexErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.build, color: Colors.orange, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Index Required',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Firestore needs an index to run this query efficiently.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: Column(
                children: [
                  const Text(
                    '📋 Quick Fix:',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Open the URL below in your browser',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'https://console.firebase.google.com/v1/r/project/gym-flow-57446/firestore/indexes',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      // You could use url_launcher package here
                      print('Open Firebase Console to create index');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('Create Index Now'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Continue with basic view
                Navigator.pop(context);
              },
              child: const Text('Continue with Basic View'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirestoreErrorState(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Colors.orange, size: 64),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💡 Quick Fix:',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Go to Firebase Console → Firestore → Rules',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const Text(
                    '2. Replace rules with:',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'allow read, write: if true;',
                      style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      _debugCheckBookings();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text('Test Connection After Fix'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _debugCheckBookings() async {
    print('\n🔍 DEBUG: Manual Booking Check');
    print('════════════════════════════════════════');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return;
    }

    print('👤 User ID: ${user.uid}');
    print('📧 User Email: ${user.email}');

    try {
      final snapshot = await _firestore
          .collection('equipment_bookings')
          .where('userId', isEqualTo: user.uid)
          .get();

      print('📊 Total bookings in Firestore: ${snapshot.docs.length}');

      if (snapshot.docs.isNotEmpty) {
        print('📝 Booking Details:');
        for (var doc in snapshot.docs) {
          final data = doc.data();
          print('   • ID: ${doc.id}');
          print('     Equipment: ${data['equipmentName']}');
          print('     Date: ${data['date']}');
          print('     Time: ${data['startTime']}');
          print('     UserId: ${data['userId']}');
          print('     UserEmail: ${data['userEmail']}');
          print('     ─────────────');
        }
      } else {
        print('⚠️  No bookings found for this user');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found ${snapshot.docs.length} bookings'),
          backgroundColor: snapshot.docs.isEmpty ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      print('❌ Error checking bookings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    final messages = [
      'No active bookings',
      'No upcoming bookings',
      'No completed bookings',
      'No cancelled bookings'
    ];

    final icons = [
      Icons.access_time,
      Icons.upcoming,
      Icons.check_circle,
      Icons.cancel
    ];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icons[_selectedTab], color: Colors.grey, size: 64),
          const SizedBox(height: 16),
          Text(
            messages[_selectedTab],
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 8),
          if (_selectedTab == 1) // Upcoming tab
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Book Equipment Now'),
            ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(EquipmentBooking booking) {
    String status;
    Color statusColor;
    IconData statusIcon;

    if (booking.isCancelled) {
      status = 'Cancelled';
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    } else if (booking.isCompleted) {
      status = 'Completed';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (booking.isUpcoming) {
      status = 'Upcoming';
      statusColor = Colors.blue;
      statusIcon = Icons.upcoming;
    } else {
      status = 'Active';
      statusColor = Colors.orange;
      statusIcon = Icons.access_time;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          // Booking Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.equipmentName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: Colors.grey[400], size: 14),
                          const SizedBox(width: 4),
                          Text(
                            booking.formattedDate,
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
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Booking Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  Icons.access_time,
                  'Time',
                  '${booking.formattedStartTime} - ${booking.formattedEndTime}',
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.timer,
                  'Duration',
                  '${booking.duration} minutes',
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  Icons.info,
                  'Status',
                  booking.isCancelled ? 'Cancelled' : 'Confirmed',
                ),
                const SizedBox(height: 12),

                // Action Buttons
                if (!booking.isCancelled && booking.isUpcoming)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showCancelDialog(booking),
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text('Cancel Booking'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[400], size: 16),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showCancelDialog(EquipmentBooking booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Cancel Booking',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to cancel your booking for "${booking.equipmentName}"?\n\nDate: ${booking.formattedDate}\nTime: ${booking.formattedStartTime}',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Keep Booking',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelBooking(booking);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking(EquipmentBooking booking) async {
    try {
      await _bookingService.cancelBooking(booking.id!);

      // Reload stats
      _loadBookingStats();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text('Booking for ${booking.equipmentName} cancelled'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Failed to cancel: $e'),
        ),
      );
    }
  }
}
