import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:louvorja_piano_mobile/core/services/sync/operator_state_client.dart';
import 'package:louvorja_piano_mobile/data/repositories/liturgy_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('produtor avisa o agendador somente após persistir a outbox', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var notifications = 0;
    OperatorStateClient.onEnqueued = (storage) {
      notifications++;
      expect(
        storage.getString(OperatorStateClient.outboxStorageKey),
        contains('liturgy::pt'),
      );
    };
    addTearDown(() => OperatorStateClient.onEnqueued = null);
    await OperatorStateClient(
      prefs,
    ).enqueueLiturgy(LiturgyRepository.emptyState());
    expect(notifications, 1);
  });
}
