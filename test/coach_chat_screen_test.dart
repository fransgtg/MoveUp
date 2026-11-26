import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moveup/screens/coach_chat_screen.dart';
import 'package:moveup/services/coach_service.dart';

void main() {
  final coach = CoachService.instance;

  setUp(coach.reset);
  tearDown(coach.reset);

  testWidgets('contoh pertanyaan membuka percakapan dan Coach menjawab', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CoachChatScreen()));
    expect(find.text('Mode offline'), findsOneWidget);

    final send = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Kirim pesan',
    );
    expect(tester.widget<IconButton>(send).onPressed, isNull);

    await tester.tap(find.text('Makan sebelum latihan'));
    await tester.pump();
    expect(find.bySemanticsLabel('Coach sedang mengetik'), findsOneWidget);
    expect(find.textContaining('Apa yang sebaiknya aku makan'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.textContaining('Panduan makan untuk latihan'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Terima kasih');
    await tester.pump();
    await tester.tap(send);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sama-sama'), findsOneWidget);

    await tester.tap(find.byTooltip('Percakapan baru'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mulai Baru'));
    await tester.pumpAndSettle();
    expect(coach.messages, isEmpty);
    expect(find.text('Makan sebelum latihan'), findsOneWidget);
  });
}
