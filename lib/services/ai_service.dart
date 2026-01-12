import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/equipment.dart';

class AIService {
  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _userLevel;
  String? _userGoal;

  String? _lastWorkoutPlan;

  bool _debugMode = true;

  AIService() {
    _debug('Gemini key loaded: ${_apiKey.isNotEmpty}');
  }

  void _debug(String msg) {
    if (_debugMode) {
      print('🤖 AIService: $msg');
    }
  }

  /* ───────── USER SETUP ───────── */

  void setUserPreferences({
    required String level,
    required String goal,
  }) {
    _userLevel = level;
    _userGoal = goal;
  }

  bool _isValidApiKey() {
    return _apiKey.isNotEmpty && _apiKey.startsWith('AIza');
  }

  /* ───────── WORKOUT GENERATION ───────── */

  Future<String> getPersonalizedWorkout() async {
    if (_userLevel == null || _userGoal == null) {
      return 'Please select fitness level and goal first.';
    }

    if (!_isValidApiKey()) {
      return _offlineWorkout();
    }

    final equipment = await _getAvailableEquipment();

    final equipmentContext = equipment.isEmpty
        ? 'No equipment available.'
        : equipment.map((e) => '- ${e.name} (${e.category})').join('\n');

    final prompt = '''
You are a certified personal trainer.

IMPORTANT RULES:
- No markdown symbols such as **, ---, ###
- No AI phrases like "As an AI", "Alright", apologies, or meta comments
- Keep explanations short and practical
- Use clear formatting with plain text only

USER:
- Level: $_userLevel
- Goal: $_userGoal
- Time: 45 minutes

AVAILABLE GYMFLOW EQUIPMENT:
$equipmentContext

FORMAT REQUIREMENTS:
- Clear section titles
- Each exercise MUST include the machine name used in GymFlow
- Use this format for exercises:

Exercise Name
Machine: <exact GymFlow machine name>
Short explanation on how to perform the exercise

SECTIONS TO INCLUDE:
- Warm Up (very short)
- Main Workout
- Cardio (if suitable)
- Cool Down (very short)

Return only the workout plan.
''';

    String response = await _callGemini(prompt);

    // 🔁 AUTO-CONTINUE IF CUT OFF
    if (_looksIncomplete(response)) {
      _debug('Response incomplete, requesting continuation...');
      final continuation = await _callGemini(
        'Continue exactly from where you stopped. Do not repeat. No extra commentary.',
      );
      response = '$response\n\n$continuation';
    }

    response = _sanitizeResponse(response);

    _lastWorkoutPlan = response;
    return response;
  }

  /* ───────── FOLLOW-UP QUESTIONS ───────── */

  Future<String> answerQuestion(String question) async {
    if (_lastWorkoutPlan == null) {
      return 'Please generate a workout first.';
    }

    final prompt = '''
You are a personal trainer.

RULES:
- Answer directly
- No markdown
- No AI self references

WORKOUT:
$_lastWorkoutPlan

QUESTION:
$question
''';

    final response = await _callGemini(prompt);
    return _sanitizeResponse(response);
  }

  /* ───────── GEMINI CALL ───────── */

  Future<String> _callGemini(String prompt) async {
    try {
      final uri = Uri.parse('$_baseUrl?key=$_apiKey');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 3000,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (text != null && text.toString().trim().isNotEmpty) {
          return text.toString();
        }
      }

      if (response.statusCode == 429) {
        return 'API quota exceeded. Please wait a few minutes before retrying.';
      }

      return 'Gemini API error.';
    } catch (e) {
      return 'AI service error.';
    }
  }

  /* ───────── RESPONSE CLEANER ───────── */

  String _sanitizeResponse(String text) {
    return text
        .replaceAll('**', '')
        .replaceAll('###', '')
        .replaceAll('---', '')
        .replaceAll(RegExp(r'\bAs an AI\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bAlright\b', caseSensitive: false), '')
        .trim();
  }

  /* ───────── INCOMPLETE DETECTOR ───────── */

  bool _looksIncomplete(String text) {
    final lower = text.toLowerCase();
    return !lower.contains('cool down') && !lower.contains('cool-down');
  }

  /* ───────── FIRESTORE ───────── */

  Future<List<Equipment>> _getAvailableEquipment() async {
    try {
      final snap = await _firestore
          .collection('equipment')
          .where('isAvailable', isEqualTo: true)
          .get();

      return snap.docs.map((d) => Equipment.fromMap(d.id, d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  /* ───────── OFFLINE FALLBACK ───────── */

  String _offlineWorkout() {
    return '''
OFFLINE WORKOUT

Warm Up:
Light movement 3 minutes

Main Workout:
Bodyweight exercises

Cool Down:
Stretching 2 minutes

AI unavailable.
''';
  }
}
