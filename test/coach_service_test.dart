import 'package:flutter_test/flutter_test.dart';
import 'package:moveup/services/coach_service.dart';

void main() {
  final coach = CoachService.instance;

  setUp(coach.reset);

  test('Coach menjawab secara lokal dan menyimpan percakapan', () async {
    await coach.send('  Halo  ');

    expect(coach.busy, isFalse);
    expect(coach.messages.map((m) => m.role), [ChatRole.user, ChatRole.coach]);
    expect(coach.messages.first.text, 'Halo');
    expect(coach.messages.last.text, startsWith('Halo'));
  });

  test('reset membatalkan balasan yang masih ditunggu', () async {
    final pending = coach.send('Halo');
    coach.reset();
    await pending;

    expect(coach.messages, isEmpty);
    expect(coach.busy, isFalse);
  });
}
