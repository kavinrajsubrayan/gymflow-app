import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import 'book_equipment_screen.dart';

class AIFitnessAssistantScreen extends StatefulWidget {
  const AIFitnessAssistantScreen({super.key});

  @override
  State<AIFitnessAssistantScreen> createState() =>
      _AIFitnessAssistantScreenState();
}

class _AIFitnessAssistantScreenState extends State<AIFitnessAssistantScreen> {
  final List<ChatMessage> _conversation = [];
  bool _isLoading = false;

  late AIService _aiService;

  String? _selectedLevel;
  String? _selectedGoal;
  bool _preferencesSet = false;

  final List<String> _levels = ['Beginner', 'Intermediate', 'Pro'];
  final List<String> _goals = [
    'Build Muscle',
    'Lose Weight',
    'Improve Endurance',
    'General Fitness',
  ];

  @override
  void initState() {
    super.initState();
    _aiService = AIService();
    _welcome();
  }

  void _welcome() {
    _addAI(
      'GymFlow AI Coach\n\n'
      'Choose your fitness level and goal to generate a workout.',
    );
  }

  void _setPreferences(String level, String goal) {
    _aiService.setUserPreferences(
      level: level.toLowerCase(),
      goal: goal.toLowerCase(),
    );

    setState(() {
      _selectedLevel = level;
      _selectedGoal = goal;
      _preferencesSet = true;
    });

    _addUser('Level: $level | Goal: $goal');
    _generateWorkout();
  }

  Future<void> _generateWorkout() async {
    setState(() => _isLoading = true);

    final response = await _aiService.getPersonalizedWorkout();
    _addAI(response);

    setState(() => _isLoading = false);
  }

  void _addAI(String text) {
    setState(() {
      _conversation.add(ChatMessage(text: text, isAI: true));
    });
  }

  void _addUser(String text) {
    setState(() {
      _conversation.add(ChatMessage(text: text, isAI: false));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'GymFlow AI Coach',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Hero Intro Card
            _buildHeroCard(),

            // 2. Preferences Card (only if preferences not set)
            if (!_preferencesSet) _buildPreferences(),

            // 3. Quick Action Card (only if preferences are set)
            if (_preferencesSet) _buildQuickBook(),

            // 4. Chat Conversation
            _buildChat(),

            // 5. Loading Indicator
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  // 1️⃣ Hero Intro Card
  Widget _buildHeroCard() {
    return Container(
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Your AI Fitness Coach',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Personalized workouts based on your goal and fitness level.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // 2️⃣ Upgrade Preferences UI (Card Based)
  Widget _buildPreferences() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Your Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Fitness Level Chips
          const Text(
            'Fitness Level',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _levels.map((level) {
              return ChoiceChip(
                label: Text(
                  level,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                selected: _selectedLevel == level,
                selectedColor: Colors.blue,
                backgroundColor: Colors.grey[800],
                labelStyle: TextStyle(
                  color:
                      _selectedLevel == level ? Colors.white : Colors.white70,
                ),
                onSelected: (_) => setState(() => _selectedLevel = level),
              );
            }).toList(),
          ),

          const SizedBox(height: 8),

          // Goal Chips
          const Text(
            'Fitness Goal',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _goals.map((goal) {
              return ChoiceChip(
                label: Text(
                  goal,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                selected: _selectedGoal == goal,
                selectedColor: Colors.green,
                backgroundColor: Colors.grey[800],
                labelStyle: TextStyle(
                  color: _selectedGoal == goal ? Colors.white : Colors.white70,
                ),
                onSelected: (_) => setState(() => _selectedGoal = goal),
              );
            }).toList(),
          ),

          const SizedBox(height: 8),

          // Generate Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_selectedLevel != null && _selectedGoal != null)
                  ? () => _setPreferences(_selectedLevel!, _selectedGoal!)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Generate Workout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3️⃣ Upgrade Quick Book Button (CTA Card)
  Widget _buildQuickBook() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ready to book equipment?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Secure your spot for the generated workout',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const BookEquipmentScreen(selectedCategory: 'All'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Book Now',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4️⃣ Upgrade Chat Bubbles
  Widget _buildChat() {
    return Container(
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: _conversation.length,
        itemBuilder: (_, index) {
          final message = _conversation[index];
          return Align(
            alignment:
                message.isAI ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: message.isAI ? Colors.blueGrey[800] : Colors.green[700],
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                message.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isAI;

  ChatMessage({
    required this.text,
    required this.isAI,
  });
}
