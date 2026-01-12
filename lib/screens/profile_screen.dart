// lib/screens/profile_screen.dart - UPDATED WITH RECTANGULAR CARDS
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'welcome_screen.dart';
import 'dart:async';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic> _userStats = {
    'workoutCount': 0,
    'totalBookings': 0,
    'favoriteEquipment': 'None',
    'memberSince': '',
  };
  Map<String, dynamic>? _todayBooking;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _bookingsSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserStats();
    _loadTodayBooking();
    _setupBookingsListener();
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshOnScreenFocus();
  }

  void _setupBookingsListener() {
    if (_user == null) return;

    _bookingsSubscription = _firestore
        .collection('equipment_bookings')
        .where('userId', isEqualTo: _user!.uid)
        .where('isCancelled', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      _loadUserStats();
      _loadTodayBooking();
    }, onError: (error) {
      print('Error in bookings listener: $error');
    });
  }

  void _refreshOnScreenFocus() {
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      _loadUserStats();
      _loadTodayBooking();
    }
  }

  Future<void> _loadUserStats() async {
    if (_user == null) return;

    try {
      // Load bookings from Firestore
      final bookingsSnapshot = await _firestore
          .collection('equipment_bookings')
          .where('userId', isEqualTo: _user!.uid)
          .where('isCancelled', isEqualTo: false)
          .get();

      String favoriteEquipment = 'None';
      if (bookingsSnapshot.docs.isNotEmpty) {
        final equipmentCount = <String, int>{};
        for (var doc in bookingsSnapshot.docs) {
          final equipment = doc['equipmentName'] as String? ?? 'Unknown';
          equipmentCount[equipment] = (equipmentCount[equipment] ?? 0) + 1;
        }
        if (equipmentCount.isNotEmpty) {
          favoriteEquipment = equipmentCount.entries
              .reduce((a, b) => a.value > b.value ? a : b)
              .key;
        }
      }

      setState(() {
        _userStats = {
          'totalBookings': bookingsSnapshot.docs.length,
          'favoriteEquipment': favoriteEquipment,
          'memberSince': _getMemberSinceDate(),
        };
      });
    } catch (e) {
      print('Error loading user stats: $e');
    }
  }

  Future<void> _loadTodayBooking() async {
    if (_user == null) return;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      final snapshot = await _firestore
          .collection('equipment_bookings')
          .where('userId', isEqualTo: _user!.uid)
          .where('isCancelled', isEqualTo: false)
          .where('bookingDateTime', isGreaterThanOrEqualTo: startOfDay)
          .where('bookingDateTime', isLessThan: endOfDay)
          .orderBy('bookingDateTime')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _todayBooking = snapshot.docs.first.data();
        });
      } else {
        setState(() {
          _todayBooking = null;
        });
      }
    } catch (e) {
      print('Error loading today booking: $e');
    }
  }

  Future<int> _getGymVisitCount() async {
    if (_user == null) return 0;

    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('equipment_bookings')
          .where('userId', isEqualTo: _user!.uid)
          .where('isCancelled', isEqualTo: false)
          .get();

      int completedCount = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final DateTime bookingDateTime =
            (data['bookingDateTime'] as Timestamp).toDate();
        final int durationMinutes = data['durationMinutes'] ?? 30;
        final DateTime endTime =
            bookingDateTime.add(Duration(minutes: durationMinutes));

        if (endTime.isBefore(now.subtract(const Duration(minutes: 10)))) {
          completedCount++;
        }
      }
      return completedCount;
    } catch (e) {
      print('Error calculating gym visit count: $e');
      return 0;
    }
  }

  String _getMemberSinceDate() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.metadata.creationTime != null) {
      final created = user!.metadata.creationTime!;
      return DateFormat('MMM yyyy').format(created);
    }
    return 'Oct 2024';
  }

  String _getMembershipLevel(int totalBookings) {
    if (totalBookings >= 31) return 'Pro';
    if (totalBookings >= 11) return 'Regular';
    return 'Beginner';
  }

  // Calculate membership duration in months
  String _getMembershipDuration() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.metadata.creationTime != null) {
      final created = user!.metadata.creationTime!;
      final now = DateTime.now();
      final difference = now.difference(created);
      final months = (difference.inDays / 30).floor();
      return '$months Month${months == 1 ? '' : 's'}';
    }
    return '6 Months';
  }

  Future<void> _refreshProfile() async {
    print('🔄 Manually refreshing profile data...');
    await _loadUserStats();
    await _loadTodayBooking();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? 'User';
    final userName = userEmail.split('@').first;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        backgroundColor: Colors.black,
        color: Colors.blue,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHeader(userName, userEmail),
                    const SizedBox(height: 20),

                    // Today's Booking Card
                    if (_todayBooking != null) _buildTodayBookingCard(),

                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 12),
                      child: Text(
                        'My Activity',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // REMOVED: GridView.count completely

            // NEW: Three Full-width Rectangular Cards
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // 1️⃣ Total Bookings Card
                    _buildActivityCard(
                      icon: Icons.book_online_rounded,
                      iconColor: Colors.blue,
                      title: 'Total Bookings',
                      value: '${_userStats['totalBookings']}',
                      subtitle: 'Equipment bookings ever made',
                    ),
                    const SizedBox(height: 12),

                    // 2️⃣ Favourite Equipment Card
                    _buildActivityCard(
                      icon: Icons.star_rounded,
                      iconColor: Colors.orange,
                      title: 'Favourite Equipment',
                      value: _userStats['favoriteEquipment'],
                      subtitle: 'Most frequently booked',
                    ),
                    const SizedBox(height: 12),

                    // 3️⃣ Membership Active Card
                    _buildActivityCard(
                      icon: Icons.timer_rounded,
                      iconColor: Colors.purple,
                      title: 'Membership Active',
                      value: _getMembershipDuration(),
                      subtitle: 'Account age / membership time',
                    ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildSettingsSection(),
                    const SizedBox(height: 24),
                    _buildLogoutButton(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(String userName, String userEmail) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue, width: 3),
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.purple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  userEmail,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.blueAccent[100],
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Member since ${_userStats['memberSince']}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Level: ${_getMembershipLevel(_userStats['totalBookings'])}',
                      style: TextStyle(
                        color: Colors.amber.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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

  Widget _buildTodayBookingCard() {
    if (_todayBooking == null) return const SizedBox.shrink();

    final bookingDateTime =
        (_todayBooking!['bookingDateTime'] as Timestamp).toDate();
    final endTime = bookingDateTime
        .add(Duration(minutes: _todayBooking!['durationMinutes'] ?? 30));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.schedule_rounded,
                color: Colors.blue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next Session',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _todayBooking!['equipmentName'] ?? 'Unknown Equipment',
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Today · ${DateFormat('h:mm a').format(bookingDateTime)} – ${DateFormat('h:mm a').format(endTime)}',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Full-width Rectangular Activity Card
  Widget _buildActivityCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2a2a2a)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            'Settings',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1a1a1a),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2a2a2a)),
          ),
          child: Column(
            children: [
              _buildSettingItem(
                icon: Icons.help_rounded,
                iconColor: Colors.green,
                title: 'Help & Support',
                subtitle: 'FAQs and contact support',
                value: '',
                onTap: _showHelpDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (value.isNotEmpty)
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showLogoutDialog,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: const Text(
          'Log Out',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.withOpacity(0.15),
          foregroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: Colors.red.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1a1a1a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: Colors.red,
                  size: 30,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Log Out?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to log out?',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2a2a2a),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _logout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Log Out',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1a1a1a),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Help & Support',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Developer:',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              const Text(
                'Kavinraj',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Contact Email:',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
              const Text(
                'kavinrajsubrayan1@gmail.com',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
