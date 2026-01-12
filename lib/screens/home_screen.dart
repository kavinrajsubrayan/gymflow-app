// lib/screens/home_screen.dart - COMPLETE FIXED VERSION WITH RED FIX BUTTON
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'book_equipment_screen.dart';
import 'ai_fitness_assistant_screen.dart';
import 'my_bookings_screen.dart';
import 'profile_screen.dart';
import '../utils/gym_occupancy_service.dart';
import '../services/booking_service.dart';
import '../models/equipment_booking.dart';
import '../widgets/equipment_status_widget.dart';
import '../services/real_time_equipment_service.dart';
import '../utils/fix_equipment_status.dart';
import 'package:flutter/foundation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isWorkingOut = false;
  int _currentOccupancy = 0;
  final int _maxOccupancy = 50;
  int _workoutDurationSeconds = 0;
  Timer? _workoutTimer;
  final GymOccupancyService _occupancyService = GymOccupancyService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BookingService _bookingService = BookingService();
  final User? _user = FirebaseAuth.instance.currentUser;
  final RealTimeEquipmentService _realTimeService = RealTimeEquipmentService();

  // Booking variables
  int _activeBookingCount = 0;
  int _upcomingBookingCount = 0;
  List<EquipmentBooking> _ongoingAndUpcomingBookings = [];
  StreamSubscription? _bookingsSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _startOccupancyListener();
    _startWorkoutTimer();

    if (_user != null) {
      _loadUserBookings();
    }

    // Start real-time service when screen loads
    _realTimeService.startRealTimeUpdates();
  }

  @override
  void dispose() {
    _workoutTimer?.cancel();
    _bookingsSubscription?.cancel();
    _realTimeService.stop(); // Stop real-time service
    super.dispose();
  }

  void _loadInitialData() async {
    print('🏠 HomeScreen - Loading initial data');

    if (_user != null) {
      final activeSession =
          await _occupancyService.getActiveUserSession(_user!.uid);
      if (activeSession != null && mounted) {
        setState(() {
          _isWorkingOut = true;
        });
        _updateWorkoutDuration();
      }
    }

    final occupancy = await _occupancyService.getCurrentOccupancy();
    if (mounted) {
      setState(() {
        _currentOccupancy = occupancy;
        _isLoading = false;
      });
    }
  }

  void _loadUserBookings() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_user == null || !mounted) return;

      print('📋 Loading user bookings for: ${_user!.uid}');

      _bookingsSubscription =
          _bookingService.getUserBookingsStream(_user!.uid).listen((bookings) {
        print('📊 Received ${bookings.length} bookings');

        // Filter for ongoing and upcoming bookings only (not completed or cancelled)
        final ongoingAndUpcoming = bookings
            .where((booking) => booking.isActive || booking.isUpcoming)
            .toList();

        // Sort: active first, then upcoming by date
        ongoingAndUpcoming.sort((a, b) {
          // Active bookings come first
          if (a.isActive && !b.isActive) return -1;
          if (!a.isActive && b.isActive) return 1;

          // Then sort by date (earliest first)
          return a.date.compareTo(b.date);
        });

        // Take only first 3 for home screen
        final displayBookings = ongoingAndUpcoming.take(3).toList();

        if (mounted) {
          setState(() {
            _activeBookingCount = bookings.where((b) => b.isActive).length;
            _upcomingBookingCount = bookings.where((b) => b.isUpcoming).length;
            _ongoingAndUpcomingBookings = displayBookings;
          });
        }
      }, onError: (error) {
        print('❌ Error loading bookings: $error');
      });
    });
  }

  void _startOccupancyListener() {
    _occupancyService.getOccupancyStream().listen((occupancy) {
      if (mounted) {
        setState(() {
          _currentOccupancy = occupancy;
        });
      }
    });
  }

  void _startWorkoutTimer() {
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isWorkingOut) {
        _updateWorkoutDuration();
      }
    });
  }

  void _updateWorkoutDuration() async {
    if (_user != null) {
      final duration = await _occupancyService.getWorkoutDuration(_user!.uid);
      if (mounted) {
        setState(() {
          _workoutDurationSeconds = duration;
        });
      }
    }
  }

  String _formatDuration(int totalSeconds) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final hours = twoDigits(totalSeconds ~/ 3600);
    final minutes = twoDigits((totalSeconds % 3600) ~/ 60);
    final seconds = twoDigits(totalSeconds % 60);
    return "$hours:$minutes:$seconds";
  }

  void _debugCheckBookings() async {
    print('\n🔍 DEBUG: Checking Booking System');
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${snapshot.docs.length} bookings'),
            backgroundColor:
                snapshot.docs.isEmpty ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error checking bookings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // NEW: Fix equipment status (Fully Booked → In Use)
  void _fixFullyBookedToInUse() async {
    print('🔥 FIXING: Changing "Fully Booked" to "In Use"');
    try {
      await fixEquipmentStatusForSingleMachine();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Equipment fixed! Now shows ORANGE for single user'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Fix error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Manual equipment status fix function with REAL-TIME check
  void _fixEquipmentStatus() async {
    print('🔧 Manually fixing equipment status with REAL-TIME check...');

    try {
      // Show current time for debugging
      final now = DateTime.now();
      print('⏰ Current server time: $now');
      print('⏰ Current device time: ${DateTime.now()}');

      // Force update all equipment with current time

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Equipment status updated with REAL-TIME check!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      print('✅ Manual equipment status fix completed');
    } catch (e) {
      print('❌ Error fixing equipment status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startWorkout() async {
    if (_user == null) return;

    try {
      final userName = _user!.email?.split('@')[0] ?? 'User';
      await _occupancyService.checkIn(_user!.uid, userName);

      final quote = MotivationService.getRandomStartQuote();

      if (mounted) {
        setState(() {
          _isWorkingOut = true;
          _workoutDurationSeconds = 0;
        });

        _showMotivationDialog('Workout Started! 🎉', quote);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Error starting workout: $e'),
          ),
        );
      }
    }
  }

  Future<void> _endWorkout() async {
    if (_user == null) return;

    try {
      _occupancyService.updateAllActiveSessions();
      await _occupancyService.checkOut(_user!.uid);

      final quote = MotivationService.getRandomEndQuote();
      final workoutTime = _formatDuration(_workoutDurationSeconds);

      if (mounted) {
        setState(() {
          _isWorkingOut = false;
          _workoutDurationSeconds = 0;
        });

        _showWorkoutCompletionDialog(workoutTime, quote);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Error ending workout: $e'),
          ),
        );
      }
    }
  }

  void _showMotivationDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'LET\'S GO!',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showWorkoutCompletionDialog(String workoutTime, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Workout Complete! 🎊',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Workout Time: $workoutTime',
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'AWESOME!',
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.email?.split('@')[0] ?? 'User';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.2),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back, $userName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Welcome to GymFlow!',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          StreamBuilder<Object?>(
            stream: _bookingService.getUserBookingsStream(_user?.uid ?? ''),
            builder: (context, snapshot) {
              final isConnected =
                  snapshot.connectionState == ConnectionState.active;
              return Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 8, top: 8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isConnected ? Colors.green : Colors.red,
                  boxShadow: [
                    BoxShadow(
                      color: isConnected ? Colors.green : Colors.red,
                      blurRadius: 8,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.blue,
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStartWorkoutCard(),
                    const SizedBox(height: 24),
                    _buildOccupancySection(),
                    const SizedBox(height: 24),
                    _buildQuickBookSection(),
                    const SizedBox(height: 24),
                    _buildAIAssistantSection(),
                    const SizedBox(height: 24),

                    // AVAILABLE EQUIPMENT NOW SECTION - UPDATED
                    _buildAvailableEquipmentSection(),
                    const SizedBox(height: 24),

                    // ONGOING & UPCOMING BOOKINGS SECTION
                    _buildOngoingUpcomingBookingsSection(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      floatingActionButton: !kReleaseMode
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // 🔥 RED FIX BUTTON
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: FloatingActionButton(
                    heroTag: null,
                    onPressed: _fixFullyBookedToInUse,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.warning, color: Colors.white),
                    tooltip: 'FIX: Change Fully Booked to In Use',
                  ),
                ),

                // Purple debug time button
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: FloatingActionButton(
                    heroTag: null,
                    onPressed: () async {
                      print('🕒 Running time debug...');
                      try {
                        final now = DateTime.now();
                        print('⏰ Current time: $now');
                      } catch (e) {
                        print('❌ Debug error: $e');
                      }
                    },
                    backgroundColor: Colors.purple,
                    child: const Icon(Icons.timer, color: Colors.white),
                  ),
                ),

                // Orange refresh button
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: FloatingActionButton(
                    heroTag: null,
                    onPressed: _fixEquipmentStatus,
                    backgroundColor: Colors.orange,
                    child: const Icon(Icons.refresh, color: Colors.white),
                  ),
                ),

                // Blue debug button
                FloatingActionButton(
                  heroTag: null,
                  onPressed: _debugCheckBookings,
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.bug_report, color: Colors.white),
                ),
              ],
            )
          : null,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildStartWorkoutCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue, Colors.purple],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'START WORKOUT',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isWorkingOut
                ? 'Great job! Keep pushing! 🚀'
                : 'Ready to start your workout?',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          if (_isWorkingOut) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.timer, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(_workoutDurationSeconds),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isWorkingOut ? _endWorkout : _startWorkout,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isWorkingOut ? Colors.red : Colors.white,
                foregroundColor: _isWorkingOut ? Colors.white : Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                _isWorkingOut ? 'END WORKOUT' : 'START WORKOUT',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOccupancySection() {
    double occupancyPercentage = _currentOccupancy / _maxOccupancy;
    String occupancyLevel = _currentOccupancy < 10
        ? 'Light'
        : _currentOccupancy < 30
            ? 'Moderate'
            : 'Busy';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gym Occupancy',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$_currentOccupancy/$_maxOccupancy people currently working out',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                occupancyLevel,
                style: TextStyle(
                  color: _getOccupancyColor(occupancyLevel),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_currentOccupancy/$_maxOccupancy',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: occupancyPercentage.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.green, Colors.blue],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickBookSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Book Equipment',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildEquipmentCategory('Cardio', Icons.directions_run),
            _buildEquipmentCategory('Free Weights', Icons.fitness_center),
            _buildEquipmentCategory('Functional', Icons.sports_gymnastics),
            _buildEquipmentCategory('Strength', Icons.arrow_upward),
          ],
        ),
      ],
    );
  }

  Widget _buildEquipmentCategory(String title, IconData icon) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookEquipmentScreen(selectedCategory: title),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.blue, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIAssistantSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Fitness Assistant',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Quick help with workouts & equipment',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AIFitnessAssistantScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Get AI Help',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Available Equipment Now Section
  Widget _buildAvailableEquipmentSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: EquipmentStatusWidget(
        showQuickBook: true,
      ),
    );
  }

  Widget _buildOngoingUpcomingBookingsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ongoing & Upcoming',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  if (_activeBookingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            '$_activeBookingCount active',
                            style: const TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_upcomingBookingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            '$_upcomingBookingCount upcoming',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Your current and upcoming equipment reservations',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          if (_ongoingAndUpcomingBookings.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: const Column(
                children: [
                  Icon(
                    Icons.event_available,
                    color: Colors.grey,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No active or upcoming bookings',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Book equipment to see them here',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                ..._ongoingAndUpcomingBookings.map(
                    (booking) => _buildOngoingUpcomingBookingCard(booking)),
                const SizedBox(height: 16),
              ],
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyBookingsScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Colors.blue),
                ),
              ),
              child: const Text('View All Bookings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOngoingUpcomingBookingCard(EquipmentBooking booking) {
    final isActive = booking.isActive;
    final status = isActive ? 'Active Now' : 'Upcoming';
    final statusColor = isActive ? Colors.green : Colors.blue;
    final statusIcon = isActive ? Icons.access_time_filled : Icons.upcoming;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Booking details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        booking.equipmentName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                        color: Colors.grey[400], size: 12),
                    const SizedBox(width: 4),
                    Text(
                      booking.formattedDate,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time, color: Colors.grey[400], size: 12),
                    const SizedBox(width: 4),
                    Text(
                      booking.formattedStartTime,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (isActive) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.timer, color: Colors.grey[400], size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${booking.duration} min session',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: const Border(
          top: BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index != 0) {
            setState(() {
              _currentIndex = index;
            });

            switch (index) {
              case 1:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        BookEquipmentScreen(selectedCategory: 'All'),
                  ),
                ).then((_) {
                  setState(() {
                    _currentIndex = 0;
                  });
                });
                break;
              case 2: // ✅ FIX: Added AI tab navigation
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AIFitnessAssistantScreen(),
                  ),
                ).then((_) {
                  setState(() {
                    _currentIndex = 0;
                  });
                });
                break;
              case 3:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                ).then((_) {
                  setState(() {
                    _currentIndex = 0;
                  });
                });
                break;
            }
          }
        },
        backgroundColor: Colors.black,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Book',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.smart_toy),
            label: 'AI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Color _getOccupancyColor(String level) {
    switch (level) {
      case 'Light':
        return Colors.green;
      case 'Moderate':
        return Colors.yellow;
      case 'Busy':
        return Colors.orange;
      default:
        return Colors.white;
    }
  }
}

class MotivationService {
  static final List<String> _startQuotes = [
    "The only bad workout is the one that didn't happen.",
    "Don't stop when you're tired. Stop when you're done.",
    "Your body can stand almost anything. It's your mind you have to convince.",
    "The pain you feel today will be the strength you feel tomorrow.",
    "Success starts with self-discipline.",
  ];

  static final List<String> _endQuotes = [
    "Great work! Consistency beats intensity every time.",
    "Another step forward in your fitness journey!",
    "The hardest part is over. You showed up and did the work.",
    "Be proud of yourself for not giving up.",
    "Every rep counts. You're getting stronger every day!",
  ];

  static String getRandomStartQuote() {
    final random = DateTime.now().millisecond % _startQuotes.length;
    return _startQuotes[random];
  }

  static String getRandomEndQuote() {
    final random = DateTime.now().millisecond % _endQuotes.length;
    return _endQuotes[random];
  }
}
