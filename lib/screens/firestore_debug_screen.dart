import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/firestore_debug_helper.dart';

class FirestoreDebugScreen extends StatefulWidget {
  const FirestoreDebugScreen({super.key});

  @override
  State<FirestoreDebugScreen> createState() => _FirestoreDebugScreenState();
}

class _FirestoreDebugScreenState extends State<FirestoreDebugScreen> {
  String _logOutput = '';
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();

  void _addLog(String message) {
    setState(() {
      _logOutput = '$_logOutput\n$message';
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  Future<void> _runFullDiagnostic() async {
    setState(() {
      _isLoading = true;
      _logOutput = 'Running diagnostics...\n';
    });

    await FirestoreDebugHelper.debugFirebaseSetup();
    await FirestoreDebugHelper.checkFirestoreRules();
    await FirestoreDebugHelper.checkInternetConnection();

    setState(() {
      _isLoading = false;
      _logOutput += '\nDiagnostic complete';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Firestore Debug'),
        backgroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Text(
            _logOutput.isEmpty ? 'No logs yet' : _logOutput,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),

      // ✅ FIXED FLOATING ACTION BUTTON
      floatingActionButton: FloatingActionButton(
        heroTag: null, // 🔥 REQUIRED FIX
        onPressed: _runFullDiagnostic,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.play_arrow),
      ),
    );
  }
}
