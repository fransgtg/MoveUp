import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:moveup/services/activity_store.dart';
import 'package:moveup/services/goal_store.dart';
import 'package:moveup/services/local_coach.dart';
import 'package:moveup/services/profile_service.dart';
import 'package:moveup/utils/format.dart';

// Kunci dan alamat API dibaca saat build, bukan ditulis di kode:
//   flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-...
// COACH_API_URL bisa diarahkan ke server perantara (mis. Cloud Function) supaya kunci
// tidak ikut terpasang di aplikasi rilis.
const _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
const _apiUrl = String.fromEnvironment('COACH_API_URL', defaultValue: 'https://api.anthropic.com/v1/messages');

const _model = 'claude-opus-5-5';

// Instruksi tetap di depan supaya bisa di-cache; data pengguna menyusul di blok terpisah
const _instructions = '''
Kamu adalah MoveUp Coach, pelatih kebugaran virtual di aplikasi MoveUp untuk lari, bersepeda, jalan, mendaki, dan olahraga lain.

Cara menjawab:
- Pakai bahasa Indonesia yang santai, hangat, dan memotivasi tanpa menghakimi. Sapa pengguna dengan nama depannya bila wajar.
- Jawab singkat dan praktis: biasanya 2-5 kalimat atau daftar pendek. Layar ponsel itu kecil.
- Gunakan data latihan pengguna di bawah bila relevan, dan sebut angkanya secara spesifik. Jangan mengarang aktivitas yang tidak ada di data.
- Sesuaikan saran dengan level kebugaran pengguna. Untuk pemula, utamakan konsistensi dan kenaikan beban bertahap (sekitar 10% per minggu).
- Kamu bukan dokter. Untuk nyeri, cedera, sesak napas, pusing, atau kondisi medis, sarankan berhenti berlatih dan berkonsultasi dengan tenaga kesehatan.
- Jika pertanyaan di luar topik kebugaran, gizi olahraga, pemulihan, atau penggunaan aplikasi MoveUp, arahkan kembali dengan sopan.
- Jangan memakai heading markdown. Boleh memakai daftar dengan tanda "-" dan teks **tebal** seperlunya.
''';

enum ChatRole { user, coach }

class ChatMessage {
  ChatMessage(this.role, this.text);

  final ChatRole role;
  String text;
}

class CoachException implements Exception {
  CoachException(this.message);

  final String message;

  @override
  String toString() => message;
}

// Percakapan dengan MoveUp Coach. Disimpan selama aplikasi berjalan supaya
// riwayat tidak hilang saat pengguna keluar-masuk layar chat.
class CoachService extends ChangeNotifier {
  CoachService._();

  static final instance = CoachService._();

  // Hanya untuk tes: menggantikan kunci dari --dart-define
  @visibleForTesting
  static String? apiKeyOverride;

  static String get _key => apiKeyOverride ?? _apiKey;

  // Dengan kunci API, Coach memakai Claude; tanpa kunci, Coach offline (LocalCoach) yang menjawab
  static bool get isOnline => _key.isNotEmpty;

  final List<ChatMessage> messages = [];
  bool _busy = false;
  String? _error;
  // Ringkasan data pengguna diambil sekali per percakapan agar awalan prompt tetap
  // sama setiap giliran (syarat prompt caching)
  String? _context;
  http.Client? _client;
  // Penanda jawaban offline yang sedang "diketik"; reset() mengosongkannya untuk membatalkan
  Object? _localTurn;

  bool get busy => _busy;
  String? get error => _error;

  // Pertanyaan yang gagal terkirim, supaya layar bisa mengembalikannya ke kotak input
  String? takeFailedQuestion() {
    final q = _failedQuestion;
    _failedQuestion = null;
    return q;
  }

  String? _failedQuestion;

  void reset() {
    _client?.close();
    _client = null;
    _localTurn = null;
    messages.clear();
    _busy = false;
    _error = null;
    _failedQuestion = null;
    _context = null;
    notifyListeners();
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _busy) return;
    if (!isOnline) return _answerOffline(trimmed);

    _context ??= _buildContext(DateTime.now());
    final question = ChatMessage(ChatRole.user, trimmed);
    final reply = ChatMessage(ChatRole.coach, '');
    messages.addAll([question, reply]);
    _busy = true;
    _error = null;
    // Satu koneksi per pertanyaan; reset() menutupnya untuk membatalkan jawaban yang sedang mengalir
    final client = _client = http.Client();
    notifyListeners();

    try {
      await for (final chunk in _stream(client, reply)) {
        reply.text += chunk;
        notifyListeners();
      }
      if (reply.text.trim().isEmpty) throw CoachException('Coach tidak memberi jawaban. Coba ulangi pertanyaanmu.');
    } catch (e) {
      // Kalau percakapan sudah di-reset, kegagalan ini milik percakapan lama dan diabaikan
      if (_client == client) {
        // Pesan gagal dibuang supaya riwayat yang dikirim berikutnya tetap berpasangan user/coach
        messages
          ..remove(question)
          ..remove(reply);
        _error = e is CoachException ? e.message : 'Tidak bisa terhubung ke Coach. Periksa koneksi internet.';
        _failedQuestion = trimmed;
      }
    } finally {
      client.close();
      if (_client == client) {
        _client = null;
        _busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> _answerOffline(String question) async {
    final reply = ChatMessage(ChatRole.coach, '');
    messages.addAll([ChatMessage(ChatRole.user, question), reply]);
    _busy = true;
    _error = null;
    final turn = _localTurn = Object();
    notifyListeners();

    // Jeda singkat supaya terasa seperti dibalas, bukan muncul seketika
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (_localTurn != turn) return;

    reply.text = LocalCoach(
      profile: ProfileService.instance.profile,
      activities: ActivityStore.instance.activities,
      goals: GoalStore.instance.goals,
      now: DateTime.now(),
    ).reply(question);
    _localTurn = null;
    _busy = false;
    notifyListeners();
  }

  // Mengirim seluruh riwayat dan mengalirkan teks jawaban sepotong demi sepotong (SSE)
  Stream<String> _stream(http.Client client, ChatMessage reply) async* {
    final body = {
      'model': _model,
      'max_tokens': 4096,
      'stream': true,
      // Chat butuh respons cepat; effort rendah cukup untuk saran latihan sehari-hari
      'output_config': {'effort': 'low'},
      // Jika model utama menolak, server otomatis mencoba model cadangan yang sesuai
      'fallbacks': 'default',
      'cache_control': {'type': 'ephemeral'},
      'system': [
        {'type': 'text', 'text': _instructions},
        {'type': 'text', 'text': _context!},
      ],
      'messages': [
        // Pesan coach yang sedang ditulis masih kosong, jadi tidak ikut dikirim
        for (final m in messages.where((m) => m != reply))
          {'role': m.role == ChatRole.user ? 'user' : 'assistant', 'content': m.text},
      ],
    };

    final request = http.Request('POST', Uri.parse(_apiUrl))
      ..headers.addAll({
        'content-type': 'application/json',
        'x-api-key': _key,
        'anthropic-version': '2023-06-01',
        'anthropic-beta': 'server-side-fallback-2026-07-01',
      })
      ..body = jsonEncode(body);

    final response = await client.send(request).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      final raw = await response.stream.bytesToString();
      throw CoachException(_httpError(response.statusCode, raw));
    }

    var event = '';
    await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
        continue;
      }
      if (!line.startsWith('data:')) continue;
      final data = jsonDecode(line.substring(5).trim()) as Map<String, dynamic>;

      switch (event) {
        case 'content_block_start':
          // Saat model cadangan mengambil alih, teks sebagian dari model pertama tidak dipakai
          if ((data['content_block'] as Map?)?['type'] == 'fallback') reply.text = '';
        case 'content_block_delta':
          final delta = data['delta'] as Map<String, dynamic>;
          if (delta['type'] == 'text_delta') yield delta['text'] as String;
        case 'message_delta':
          final stop = (data['delta'] as Map<String, dynamic>)['stop_reason'];
          if (stop == 'refusal') {
            throw CoachException('Maaf, Coach tidak bisa membantu pertanyaan itu. Coba tanyakan hal lain seputar latihan.');
          }
        case 'error':
          final message = (data['error'] as Map?)?['message'] ?? 'Terjadi kesalahan pada server.';
          throw CoachException('Coach sedang sibuk: $message');
      }
    }
  }

  static String _httpError(int status, String raw) {
    String? detail;
    try {
      detail = ((jsonDecode(raw) as Map)['error'] as Map?)?['message'] as String?;
    } catch (_) {}
    return switch (status) {
      401 || 403 => 'Kunci API tidak valid atau tidak punya akses.',
      429 => 'Terlalu banyak permintaan. Tunggu sebentar lalu coba lagi.',
      >= 500 => 'Server Coach sedang bermasalah. Coba lagi nanti.',
      _ => 'Permintaan ditolak ($status)${detail == null ? '' : ': $detail'}',
    };
  }

  // Ringkasan profil, target, dan aktivitas terbaru sebagai bahan saran yang personal
  static String _buildContext(DateTime now) {
    final profile = ProfileService.instance.profile;
    final activities = ActivityStore.instance.activities;
    final weekStart = startOfWeek(now);
    final week = ActivityStore.instance.between(weekStart, weekStart.add(const Duration(days: 7)));
    final weekKm = week.fold<double>(0, (sum, a) => sum + a.km);
    final weekSeconds = week.fold<int>(0, (sum, a) => sum + a.movingSeconds);

    final b = StringBuffer('Data pengguna (diambil ${formatDate(now)} pukul ${formatTime(now)}):\n');
    if (profile != null) {
      b
        ..writeln('- Nama: ${profile.name}')
        ..writeln('- Usia: ${profile.age} tahun, ${profile.gender.label}')
        ..writeln('- Berat ${profile.weightKg} kg, tinggi ${profile.heightCm} cm, BMI ${profile.bmi.toStringAsFixed(1)} (${profile.bmiCategory})')
        ..writeln('- Level: ${profile.level.label}')
        ..writeln('- Olahraga favorit: ${profile.favoriteSports.map((s) => s.label).join(', ')}');
    }
    b.writeln('- Minggu ini: ${week.length} aktivitas, ${formatKm(weekKm * 1000)} km, ${formatDurationShort(weekSeconds)}');

    final goals = GoalStore.instance.goals;
    if (goals.isNotEmpty) {
      b.writeln('\nTarget:');
      for (final g in goals) {
        final p = g.progress(activities, now: now);
        b.writeln('- ${g.title} (${g.categoryLabel}, ${g.period.label}): '
            '${g.metric.format(p.current)} dari ${g.targetLabel}${p.completed ? ' - tercapai' : ''}');
      }
    }

    if (activities.isEmpty) {
      b.writeln('\nBelum ada aktivitas tercatat.');
    } else {
      b.writeln('\n${activities.length > 10 ? '10 aktivitas terakhir' : 'Aktivitas'} (terbaru dulu):');
      for (final a in activities.take(10)) {
        final (paceLabel, paceValue) = paceOrSpeed(a);
        b.writeln('- ${formatDate(a.startTime)}: ${a.type.label} "${a.title}", ${formatKm(a.distanceMeters)} km, '
            '${formatDuration(a.movingSeconds)}, $paceLabel $paceValue, ${a.calories} kkal');
      }
    }
    return b.toString();
  }
}
