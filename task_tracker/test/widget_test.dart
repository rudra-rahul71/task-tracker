import 'package:flutter_test/flutter_test.dart';
import 'package:task_tracker/core/database/db_service.dart';

void main() {
  test('DatabaseService singleton test', () {
    final instance1 = DatabaseService.instance;
    final instance2 = DatabaseService.instance;
    expect(instance1, same(instance2));
  });
}
