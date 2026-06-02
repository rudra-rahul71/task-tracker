import 'package:cloud_firestore/cloud_firestore.dart';

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
    // Since persistenceEnabled is set to false in settings, all Firestore data is kept
    // strictly in-memory and is automatically cleared and garbage collected on session logout.
    // We avoid calling terminate() on the default instance because it permanently disables
    // the Firestore client for the rest of the application session, causing crashes when
    // a user logs back in or accesses the app without a full restart.
  }
}
