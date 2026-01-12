import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/welcome_screen.dart';
import 'services/real_time_equipment_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load env (safe)
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  // ✅ ANDROID: Firebase is auto-initialized
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  _startRealTimeServices();

  runApp(const MyApp());
}

RealTimeEquipmentService? _realTimeService;

void _startRealTimeServices() {
  _realTimeService = RealTimeEquipmentService();
  _realTimeService!.startRealTimeUpdates();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GymFlow Fitness',
      theme: ThemeData.dark(),
      home: const WelcomeScreen(),
    );
  }
}
