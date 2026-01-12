// lib/screens/equipment_booking_screen.dart - FIXED LAYOUT VERSION
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import '../models/equipment.dart';
import '../models/equipment_booking.dart';
import '../services/booking_service.dart';

class EquipmentBookingScreen extends StatefulWidget {
  final Equipment equipment;
  const EquipmentBookingScreen({super.key, required this.equipment});

  @override
  State<EquipmentBookingScreen> createState() => _EquipmentBookingScreenState();
}

class _EquipmentBookingScreenState extends State<EquipmentBookingScreen> {
  // Date is fixed to today as per design decision
  final DateTime _selectedDate = DateTime.now();

  TimeOfDay? _selectedStartTime;
  int _selectedDuration = 30;
  bool _isLoading = false;
  final BookingService _bookingService = BookingService();
  final User? _user = FirebaseAuth.instance.currentUser;

  // State variable for existing bookings
  List<EquipmentBooking> _existingBookings = [];

  // Auto booking variables
  DateTime? _autoStartTime;
  bool _showAdvancedBooking = false;

  @override
  void initState() {
    super.initState();
    _loadExistingBookings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Book ${widget.equipment.name}',
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
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Equipment Header Card
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.withOpacity(0.3),
                    Colors.purple.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Equipment Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Icon(
                      Icons.fitness_center,
                      color: widget.equipment.isAvailableNow
                          ? Colors.green
                          : Colors.orange,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Equipment Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.equipment.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.equipment.statusBackgroundColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.equipment.category,
                                style: TextStyle(
                                  color: widget.equipment.statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.equipment.status == 'available'
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.equipment.statusText,
                                style: TextStyle(
                                  color: widget.equipment.status == 'available'
                                      ? Colors.green
                                      : Colors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.equipment.description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              color: Colors.grey[400],
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.equipment.capacityText,
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.timer,
                              color: Colors.grey[400],
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Max ${widget.equipment.maxDuration} min',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Today's Date Info
                    _buildSectionHeader(
                      'Booking for Today',
                      Icons.calendar_today,
                    ),
                    const SizedBox(height: 12),
                    _buildTodayInfoCard(),
                    const SizedBox(height: 24),

                    // Duration Section (APPLIES TO BOTH MODES)
                    _buildSectionHeader(
                      'Session Duration',
                      Icons.timer,
                    ),
                    const SizedBox(height: 16),
                    _buildDurationSelector(),
                    const SizedBox(height: 24),

                    // Next Available Time - PRIMARY CTA (ALWAYS VISIBLE)
                    _buildReserveNextTurnCard(),
                    const SizedBox(height: 20),

                    // Advanced Booking Toggle - SECONDARY CTA (ALWAYS AVAILABLE)
                    Center(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _showAdvancedBooking = !_showAdvancedBooking;
                            _autoStartTime =
                                null; // IMPORTANT: Clear auto booking
                          });
                        },
                        child: Text(
                          _showAdvancedBooking
                              ? 'Hide advanced options'
                              : 'Choose specific time',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Advanced Time Picker (only when toggled)
                    if (_showAdvancedBooking) ...[
                      _buildSectionHeader(
                        'Choose Specific Time',
                        Icons.access_time,
                      ),
                      const SizedBox(height: 12),
                      _buildTimeSelectionCard(),
                      const SizedBox(height: 20),

                      // Booking Summary - ONLY FOR ADVANCED BOOKING
                      if (_selectedStartTime != null) ...[
                        _buildBookingSummary(),
                        const SizedBox(height: 20),
                      ],

                      // Confirm Booking Button - ONLY FOR ADVANCED BOOKING
                      _buildConfirmButton(),
                      const SizedBox(height: 20),
                    ],

                    const SizedBox(height: 40), // Increased bottom spacing
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayInfoCard() {
    final today = DateTime.now();
    final formattedDate = _formatDate(today);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Today: $formattedDate',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReserveNextTurnCard() {
    final nextAvailableTime = _findNextAvailableStartTime();
    // Check if equipment is available now (within next 5 minutes)
    final isNowAvailable = nextAvailableTime
        .isBefore(DateTime.now().add(const Duration(minutes: 5)));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isNowAvailable
            ? Colors.green.withOpacity(0.15)
            : Colors.blue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isNowAvailable ? Colors.green : Colors.blue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isNowAvailable ? Icons.done_all : Icons.access_time,
                color: isNowAvailable ? Colors.green : Colors.blue,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isNowAvailable ? 'Available Now!' : 'Next Available',
                  style: TextStyle(
                    color: isNowAvailable ? Colors.green : Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDateTime(nextAvailableTime),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You will start after the current session ends',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Duration: $_selectedDuration minutes',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 130, // Slightly wider for new text
                      child: ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                // 🔴 IMPORTANT CHANGE: Reset advanced mode state
                                setState(() {
                                  _showAdvancedBooking = false;
                                  _selectedStartTime = null;
                                });

                                setState(() => _isLoading = true);

                                try {
                                  final user = _user;
                                  if (user == null) {
                                    throw Exception('User not logged in');
                                  }

                                  if (widget.equipment.id == null) {
                                    throw Exception('Equipment ID is missing');
                                  }

                                  print(
                                      '\n🎯 Creating Reserve Next Turn booking...');
                                  print(
                                      '   Equipment: ${widget.equipment.name} (${widget.equipment.id})');
                                  print('   Start Time: ${_formatDateTime(
                                    nextAvailableTime,
                                  )}');
                                  print(
                                      '   Duration: $_selectedDuration minutes');

                                  // Create booking object
                                  final booking = EquipmentBooking(
                                    userId: user.uid,
                                    userEmail: user.email ?? user.uid,
                                    equipmentId: widget.equipment.id!,
                                    equipmentName: widget.equipment.name,
                                    date: _selectedDate,
                                    startTime: TimeOfDay(
                                        hour: nextAvailableTime.hour,
                                        minute: nextAvailableTime.minute),
                                    duration: _selectedDuration,
                                    isCancelled: false,
                                    createdAt: DateTime.now(),
                                  );

                                  // ✅ Service-level validation and save
                                  await _bookingService.createBooking(booking);

                                  print('✅ Reserve Next Turn booking created!');

                                  setState(() => _isLoading = false);

                                  // Show success and navigate back
                                  _showBookingSuccessDialog(nextAvailableTime);
                                } catch (e) {
                                  print('❌ Reserve Next Turn failed: $e');
                                  setState(() => _isLoading = false);
                                  _showErrorDialog(
                                      'Booking Failed', e.toString());
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isNowAvailable ? Colors.green : Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Reserve Next Turn',
                                style: TextStyle(
                                  fontSize: 14,
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
          const SizedBox(height: 8),
          if (_existingBookings.isNotEmpty)
            Text(
              'Based on ${_existingBookings.length} existing booking${_existingBookings.length > 1 ? 's' : ''}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeSelectionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildTimeButton(
              'Select Start Time', _selectedStartTime, _selectStartTime),
          const SizedBox(height: 16),
          if (_selectedStartTime != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue),
              ),
              child: Column(
                children: [
                  Text(
                    'Selected: ${_formatTimeOfDay(_selectedStartTime!)}',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ends: ${_formatTimeOfDay(_calculateEndTime(_selectedStartTime!))}',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeButton(String label, TimeOfDay? time, VoidCallback onTap) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: time != null ? Colors.blue : Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: time != null ? Colors.blue : Colors.grey[600]!,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.access_time,
                  color: time != null ? Colors.white : Colors.grey[300],
                ),
                const SizedBox(width: 8),
                Text(
                  time != null ? _formatTimeOfDay(time) : 'Tap to select time',
                  style: TextStyle(
                    color: time != null ? Colors.white : Colors.grey[300],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationSelector() {
    // Duration selector is always visible and applies to both modes
    final durations = _getAvailableDurations();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: durations.map((duration) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDuration = duration;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _selectedDuration == duration
                  ? Colors.blue
                  : Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedDuration == duration
                    ? Colors.blue
                    : Colors.grey[600]!,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  color: _selectedDuration == duration
                      ? Colors.white
                      : Colors.grey[400],
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '$duration min',
                  style: TextStyle(
                    color: _selectedDuration == duration
                        ? Colors.white
                        : Colors.grey[300],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBookingSummary() {
    final startTime = _selectedStartTime != null
        ? DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            _selectedStartTime!.hour,
            _selectedStartTime!.minute,
          )
        : null;

    if (startTime == null) return const SizedBox.shrink();

    final endTime = startTime.add(Duration(minutes: _selectedDuration));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Manual Booking Summary',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Equipment', widget.equipment.name),
          _buildSummaryRow('Category', widget.equipment.category),
          _buildSummaryRow('Date', _formatDate(_selectedDate)),
          _buildSummaryRow('Start Time', _formatDateTime(startTime)),
          _buildSummaryRow('End Time', _formatDateTime(endTime)),
          _buildSummaryRow('Duration', '$_selectedDuration minutes'),
          _buildSummaryRow('Status', 'Ready to confirm'),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    // Confirm button only appears for advanced booking with selected time
    if (!_showAdvancedBooking || _selectedStartTime == null) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _confirmBooking,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 4,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.book_online, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Confirm Booking',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _selectStartTime() async {
    final now = DateTime.now();
    final isToday = _selectedDate.day == now.day &&
        _selectedDate.month == now.month &&
        _selectedDate.year == now.year;

    TimeOfDay initialTime;
    if (_selectedStartTime != null) {
      initialTime = _selectedStartTime!;
    } else {
      // Default to current time + 30 minutes
      initialTime = TimeOfDay(
        hour: now.hour,
        minute: (now.minute + 30) % 60,
      );
      // If adding 30 minutes goes to next hour
      if (now.minute + 30 >= 60) {
        initialTime =
            TimeOfDay(hour: now.hour + 1, minute: (now.minute + 30) - 60);
      }
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.grey,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.grey[900],
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      // ✅ Layer 1: Check if selected time is in the past (for today)
      if (isToday && !_isTimeInFuture(picked)) {
        _showErrorDialog('Invalid Time',
            'You cannot select a time that has already passed. Please select a future time.');
        return;
      }

      // ✅ Layer 2: UI-level overlap check
      final selectedStart = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        picked.hour,
        picked.minute,
      );
      final selectedEnd =
          selectedStart.add(Duration(minutes: _selectedDuration));

      for (final booking in _existingBookings) {
        if (selectedStart.isBefore(booking.bookingEndTime) &&
            selectedEnd.isAfter(booking.bookingDateTime)) {
          _showErrorDialog('Time Slot Unavailable',
              'This time slot overlaps with an existing booking. Please choose a different time.');
          return;
        }
      }

      setState(() {
        _selectedStartTime = picked;
        _autoStartTime = null;
      });
    }
  }

  Future<void> _loadExistingBookings() async {
    if (widget.equipment.id == null) return;

    try {
      final bookings = await _bookingService.getBookingsForEquipmentAndDate(
          widget.equipment.id!, _selectedDate);

      setState(() {
        _existingBookings = bookings;
        // Auto-calculate next available time
        _autoStartTime = _findNextAvailableStartTime();
      });

      print(
          '📅 Loaded ${bookings.length} existing bookings for ${_formatDate(_selectedDate)}');
    } catch (e) {
      print('❌ Error loading bookings: $e');
    }
  }

  // Calculate next available start time based on existing bookings
  DateTime _findNextAvailableStartTime() {
    DateTime cursor = DateTime.now();

    // Add buffer (5 minutes from now) for realistic booking
    cursor = cursor.add(const Duration(minutes: 5));

    // Round up to nearest 15 minutes for clean scheduling
    final minute = cursor.minute;
    final remainder = minute % 15;
    if (remainder != 0) {
      cursor = cursor.add(Duration(minutes: 15 - remainder));
    }

    // Check against existing bookings
    for (final booking in _existingBookings) {
      if (cursor.isBefore(booking.bookingEndTime) &&
          cursor.isAfter(booking.bookingDateTime)) {
        // If cursor is within a booking period, move to end of that booking
        cursor = booking.bookingEndTime;

        // Round up to nearest 15 minutes after booking ends
        final minute = cursor.minute;
        final remainder = minute % 15;
        if (remainder != 0) {
          cursor = cursor.add(Duration(minutes: 15 - remainder));
        }
      }
    }

    return cursor; // ✅ 24-hour gym - no time restrictions
  }

  bool _isTimeInFuture(TimeOfDay time) {
    final now = DateTime.now();
    final isToday = _selectedDate.day == now.day &&
        _selectedDate.month == now.month &&
        _selectedDate.year == now.year;

    if (!isToday) return true; // Future dates are always valid

    final selectedTime = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    return selectedTime.isAfter(now);
  }

  TimeOfDay _calculateEndTime(TimeOfDay startTime) {
    final totalMinutes =
        startTime.hour * 60 + startTime.minute + _selectedDuration;
    final hour = totalMinutes ~/ 60;
    final minute = totalMinutes % 60;
    return TimeOfDay(hour: hour, minute: minute);
  }

  List<int> _getAvailableDurations() {
    final maxDuration = widget.equipment.maxDuration;
    final durations = <int>[];

    if (maxDuration >= 15) durations.add(15);
    if (maxDuration >= 30) durations.add(30);
    if (maxDuration >= 45) durations.add(45);
    if (maxDuration >= 60) durations.add(60);
    if (maxDuration >= 90) durations.add(90);
    if (maxDuration >= 120) durations.add(120);

    return durations.isEmpty ? [30] : durations;
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _confirmBooking() async {
    // This is only for advanced booking path
    if (_selectedStartTime == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _user;
      if (user == null) {
        throw Exception('User not logged in');
      }

      if (widget.equipment.id == null) {
        throw Exception('Equipment ID is missing');
      }

      // Create start time from selected time
      final startTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedStartTime!.hour,
        _selectedStartTime!.minute,
      );

      print('\n🎯 Creating advanced booking...');
      print('   User: ${user.uid}');
      print('   Email: ${user.email}');
      print('   Equipment: ${widget.equipment.name} (${widget.equipment.id})');
      print('   Start Time: ${_formatDateTime(startTime)}');
      print('   Duration: $_selectedDuration minutes');
      print('   Type: Manual booking');

      // Create booking object
      final booking = EquipmentBooking(
        userId: user.uid,
        userEmail: user.email ?? user.uid,
        equipmentId: widget.equipment.id!,
        equipmentName: widget.equipment.name,
        date: _selectedDate,
        startTime: TimeOfDay(hour: startTime.hour, minute: startTime.minute),
        duration: _selectedDuration,
        isCancelled: false,
        createdAt: DateTime.now(),
      );

      // ✅ Layer 3: Service-level validation and save
      await _bookingService.createBooking(booking);

      print('✅ Advanced booking created successfully!');

      setState(() {
        _isLoading = false;
      });

      _showBookingSuccessDialog(startTime);
    } catch (e) {
      print('❌ Advanced booking failed: $e');

      setState(() {
        _isLoading = false;
      });

      _showErrorDialog('Booking Failed', e.toString());
    }
  }

  void _showBookingSuccessDialog(DateTime startTime) {
    final endTime = startTime.add(Duration(minutes: _selectedDuration));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text(
              'Booking Confirmed!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.equipment.name,
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildBookingDetail('Date', _formatDate(_selectedDate)),
            _buildBookingDetail('Time',
                '${_formatDateTime(startTime)} - ${_formatDateTime(endTime)}'),
            _buildBookingDetail('Duration', '$_selectedDuration minutes'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: const Text(
                '✅ Your booking is confirmed!\n✅ Time slot reserved\n✅ You can view it in your bookings',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
                (route) => false,
              );
            },
            child: const Text(
              'BACK TO HOME',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.grey,
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
      ),
    );
  }
}
