import 'package:flutter/foundation.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._constructor();

  DatabaseService._constructor();

  Future<void> clearAllData() async {
    try {
      // Clear any cached local state if needed
    } catch (e) {
      debugPrint('Error clearing local database cache: $e');
    }
  }
}
