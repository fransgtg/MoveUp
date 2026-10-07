import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:moveup/services/coach_service.dart';

// Chat MoveUp Coach dengan respons Claude API tiruan (tanpa jaringan)
void main() {
  final coach = CoachService.instance;

  setUp(() {
    CoachService.apiKeyOverride = 'test-key';
    coach.reset();
  });

  tearDown(() => CoachService.apiKeyOverride = null);

  String sse(List<(String, Map<String, dynamic>)> events) =>
      events.map((e) => 'event: ${e.$1}\ndata: ${jsonEncode(e.$2)}\n\n').join();

  (String, Map<String, dynamic>) text(String t) => (
        'content_block_delta',
        {'type': 'content_block_delta', 'index': 0, 'delta': {'type': 'text_delta', 'text': t}},
      );

  (String, Map<String, dynamic>) stop(String reason) => (
        'message_delta',
        {'type': 'message_delta', 'delta': {'stop_reason': reason}},
      );

  // Menjalankan [action] dengan klien HTTP palsu dan mencatat body permintaan yang dikirim
  Future<List<Map<String, dynamic>>> withServer(
    Future<void> Function() action, {
    required String Function(int call) reply,
    int status = 200,
  }) async {
    final requests = <Map<String, dynamic>>[];
    final client = MockClient.streaming((request, body) async {
      requests.add(jsonDecode(await body.bytesToString()) as Map<String, dynamic>);
      final payload = reply(requests.length);
      // Dipotong kecil-kecil supaya parser diuji dengan baris yang terbelah
      final chunks = [for (var i = 0; i < payload.length; i += 7) utf8.encode(payload.substring(i, (i + 7).clamp(0, payload.length)))];
      return http.StreamedResponse(Stream.fromIterable(chunks), status);
    });
    await http.runWithClient(action, () => client);
    return requests;
  }

  test('jawaban yang mengalir digabung menjadi satu pesan coach', () async {
    final requests = await withServer(
      () => coach.send('  Halo coach  '),
      reply: (_) => sse([text('Halo, '), text('ayo **lari**!'), stop('end_turn')]),
    );

    expect(coach.error, isNull);
    expect(coach.busy, isFalse);
    expect(coach.messages.map((m) => (m.role, m.text)), [
      (ChatRole.user, 'Halo coach'),
      (ChatRole.coach, 'Halo, ayo **lari**!'),
    ]);

    final body = requests.single;
    expect(body['model'], 'claude-opus-5-5');
    expect(body['stream'], isTrue);
    expect(body['fallbacks'], 'default');
    expect(body['messages'], [
      {'role': 'user', 'content': 'Halo coach'},
    ]);
  });

  test('giliran berikutnya mengirim riwayat dan konteks yang sama persis', () async {
    final requests = await withServer(
      () async {
        await coach.send('Pertama');
        await coach.send('Kedua');
      },
      reply: (call) => sse([text('Jawaban $call'), stop('end_turn')]),
    );

    expect(requests[1]['messages'], [
      {'role': 'user', 'content': 'Pertama'},
      {'role': 'assistant', 'content': 'Jawaban 1'},
      {'role': 'user', 'content': 'Kedua'},
    ]);
    // Awalan system tidak berubah antargiliran supaya prompt cache tetap terpakai
    expect(requests[1]['system'], requests[0]['system']);
  });

  test('penolakan model membuang pasangan pesan dan mengembalikan pertanyaan', () async {
    await withServer(
      () => coach.send('Pertanyaan aneh'),
      reply: (_) => sse([text('Sebagian'), stop('refusal')]),
    );

    expect(coach.messages, isEmpty);
    expect(coach.error, contains('tidak bisa membantu'));
    expect(coach.takeFailedQuestion(), 'Pertanyaan aneh');
    expect(coach.takeFailedQuestion(), isNull);
  });

  test('teks dari model yang digantikan cadangan tidak ikut ditampilkan', () async {
    await withServer(
      () => coach.send('Tanya'),
      reply: (_) => sse([
        text('Teks model pertama'),
        ('content_block_start', {'type': 'content_block_start', 'index': 1, 'content_block': {'type': 'fallback'}}),
        text('Jawaban cadangan'),
        stop('end_turn'),
      ]),
    );

    expect(coach.messages.last.text, 'Jawaban cadangan');
  });

  test('kunci API salah menampilkan pesan yang jelas', () async {
    await withServer(
      () => coach.send('Halo'),
      status: 401,
      reply: (_) => jsonEncode({'type': 'error', 'error': {'type': 'authentication_error', 'message': 'invalid x-api-key'}}),
    );

    expect(coach.messages, isEmpty);
    expect(coach.error, 'Kunci API tidak valid atau tidak punya akses.');
  });

  test('tanpa kunci API Coach offline menjawab tanpa permintaan jaringan', () async {
    CoachService.apiKeyOverride = '';
    final requests = await withServer(() => coach.send('Halo'), reply: (_) => '');

    expect(requests, isEmpty);
    expect(CoachService.isOnline, isFalse);
    expect(coach.busy, isFalse);
    expect(coach.messages.map((m) => m.role), [ChatRole.user, ChatRole.coach]);
    expect(coach.messages.last.text, startsWith('Halo'));
  });

  test('reset saat Coach offline masih mengetik membatalkan jawabannya', () async {
    CoachService.apiKeyOverride = '';
    final pending = coach.send('Halo');
    coach.reset();
    await pending;

    expect(coach.messages, isEmpty);
    expect(coach.busy, isFalse);
  });
}
