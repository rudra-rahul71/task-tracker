import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._constructor();

  DatabaseService._constructor();

  FirebaseFirestore? _firestoreInstance;

  FirebaseFirestore get firestore {
    if (_firestoreInstance == null) {
      _firestoreInstance = FirebaseFirestore.instance;
      try {
        _firestoreInstance!.settings = const Settings(
          persistenceEnabled: false,
        );
      } catch (e) {
        // Handle cases where settings can't be set (e.g. if already accessed or in tests)
      }
    }
    return _firestoreInstance!;
  }

  Future<void> clearAllData() async {
    try {
      if (_firestoreInstance != null) {
        await _firestoreInstance!.clearPersistence();
      }
    } catch (e) {
      // Handle cases where settings/persistence isn't enabled or can't be cleared (e.g. in tests)
      debugPrint('Error clearing Firestore persistence: $e');
    }
  }
}
