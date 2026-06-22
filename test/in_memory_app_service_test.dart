import 'package:ceo_communication_trainer/core/types/app_types.dart';
import 'package:ceo_communication_trainer/services/demo/in_memory_app_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cannot submit another attempt before importing AI coaching', () async {
    final service = InMemoryAppService();
    await service.signIn('coach@example.com', 'password123');
    final session = await service.openBaselineSession(0);

    await service.submitAttempt(
      sessionId: session.id,
      responseText:
          'My recommendation is to narrow scope this week so we protect quality, reduce rework, and keep leadership trust intact.',
      responseMode: ResponseMode.typed,
    );

    await expectLater(
      service.submitAttempt(
        sessionId: session.id,
        responseText:
            'My recommendation is still to narrow scope, and I would make the same call for the same business reasons.',
        responseMode: ResponseMode.typed,
      ),
      throwsA(
        predicate(
          (error) =>
              error is StateError &&
              error.toString().contains('Import AI coaching'),
        ),
      ),
    );
  });

  test('cannot finish a session before importing AI coaching', () async {
    final service = InMemoryAppService();
    await service.signIn('coach@example.com', 'password123');
    final session = await service.openBaselineSession(0);

    await service.submitAttempt(
      sessionId: session.id,
      responseText:
          'My recommendation is to narrow scope this week so we protect quality, reduce rework, and keep leadership trust intact.',
      responseMode: ResponseMode.typed,
    );

    await expectLater(
      service.finalizeSession(session.id),
      throwsA(
        predicate(
          (error) =>
              error is StateError &&
              error.toString().contains('Import AI coaching'),
        ),
      ),
    );
  });
}
