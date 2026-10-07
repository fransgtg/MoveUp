import 'package:moveup/models/activity.dart';
import 'package:moveup/models/goal.dart';
import 'package:moveup/models/user_profile.dart';
import 'package:moveup/utils/format.dart';

// Coach offline berbasis aturan: mengenali topik pertanyaan dari kata kunci, lalu menyusun
// jawaban dari data latihan pengguna. Tidak butuh internet maupun kunci API.
class LocalCoach {
  LocalCoach({required this.profile, required List<Activity> activities, required this.goals, required this.now})
      // Terbaru dulu, sama seperti urutan di ActivityStore
      : activities = [...activities]..sort((a, b) => b.startTime.compareTo(a.startTime));

  final UserProfile? profile;
  final List<Activity> activities;
  final List<Goal> goals;
  final DateTime now;

  static const _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

  String reply(String question) {
    final q = ' ${question.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')} ';
    // Cocok di awal kata supaya imbuhan tetap kena ("targetku", "makanan"); [whole] untuk kata pendek
    bool has(List<String> words, {bool whole = false}) => words.any((w) => q.contains(whole ? ' $w ' : ' $w'));

    // Keluhan kesehatan diperiksa paling awal supaya tidak tertimpa topik lain
    if (has(['sakit', 'nyeri', 'cedera', 'cidera', 'keseleo', 'terkilir', 'pusing', 'sesak', 'nyeri dada', 'pingsan', 'mual'])) {
      return _safety();
    }
    if (has(['terima kasih', 'makasih', 'thanks', 'thank'])) return _thanks();
    if (has(['rencana', 'jadwal', 'program', 'minggu depan', 'latihan apa'])) return _plan();
    if (has(['target', 'goal'])) return _goals();
    if (has(['rekor', 'terjauh', 'terlama', 'tercepat', 'terbaik']) || has(['pr'], whole: true)) return _records();
    if (has(['pace', 'kecepatan', 'lebih cepat', 'speed'])) return _pace();
    if (has(['progres', 'progress', 'perkembangan', 'minggu ini', 'statistik', 'ringkasan', 'rangkuman'])) return _progress();
    if (has(['makan', 'nutrisi', 'gizi', 'minum', 'hidrasi', 'karbo', 'protein', 'sarapan'])) return _nutrition();
    if (has(['istirahat', 'pemulihan', 'recovery', 'pegal', 'capek', 'lelah', 'tidur'])) return _recovery();
    if (has(['pemanasan', 'peregangan', 'stretching', 'warm', 'pendinginan'])) return _warmUp();
    if (has(['motivasi', 'malas', 'semangat', 'bosan'])) return _motivation();
    if (has(['bmi', 'berat badan', 'diet', 'kurus', 'gemuk', 'turun berat'])) return _bmi();
    if (has(['halo', 'hai', 'hi', 'hello', 'hey', 'assalamualaikum', 'pagi', 'siang', 'sore', 'malam'], whole: true)) {
      return _greeting();
    }
    return _help();
  }

  // ---------------------------------------------------------------------------
  // Data bantu
  // ---------------------------------------------------------------------------

  String get _firstName {
    final name = profile?.name.trim() ?? '';
    return name.isEmpty ? 'kamu' : name.split(RegExp(r'\s+')).first;
  }

  FitnessLevel get _level => profile?.level ?? FitnessLevel.beginner;

  List<Activity> _between(DateTime from, DateTime to) =>
      activities.where((a) => !a.startTime.isBefore(from) && a.startTime.isBefore(to)).toList();

  List<Activity> get _thisWeek {
    final from = startOfWeek(now);
    return _between(from, from.add(const Duration(days: 7)));
  }

  List<Activity> get _lastWeek {
    final from = startOfWeek(now).subtract(const Duration(days: 7));
    return _between(from, from.add(const Duration(days: 7)));
  }

  static double _km(Iterable<Activity> list) => list.fold(0, (sum, a) => sum + a.km);

  static int _seconds(Iterable<Activity> list) => list.fold(0, (sum, a) => sum + a.movingSeconds);

  static String _num(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  // Olahraga utama: favorit pertama, atau yang paling sering dicatat
  SportType get _mainSport {
    final favorites = profile?.favoriteSports ?? const [];
    if (favorites.isNotEmpty) return favorites.first;
    if (activities.isEmpty) return SportType.run;
    final counts = <SportType, int>{};
    for (final a in activities) {
      counts[a.type] = (counts[a.type] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  // Hari berturut-turut (sampai hari ini atau kemarin) yang punya aktivitas
  int get _streak {
    final days = {for (final a in activities) DateTime(a.startTime.year, a.startTime.month, a.startTime.day)};
    var day = DateTime(now.year, now.month, now.day);
    if (!days.contains(day)) day = day.subtract(const Duration(days: 1));
    var streak = 0;
    while (days.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ---------------------------------------------------------------------------
  // Jawaban per topik
  // ---------------------------------------------------------------------------

  String _progress() {
    final week = _thisWeek;
    final lastKm = _km(_lastWeek);
    if (week.isEmpty) {
      return 'Minggu ini $_firstName belum mencatat aktivitas. '
          '${lastKm > 0 ? 'Minggu lalu kamu menempuh **${_num(lastKm)} km**, jadi kamu pasti bisa memulai lagi. ' : ''}'
          'Coba mulai dengan sesi ringan 20-30 menit hari ini. Langkah kecil tetap dihitung!';
    }

    final km = _km(week);
    final b = StringBuffer('Minggu ini kamu sudah **${week.length} aktivitas**, total **${_num(km)} km** '
        'dalam **${formatDurationShort(_seconds(week))}**.');
    if (lastKm > 0) {
      final change = ((km - lastKm) / lastKm * 100).round();
      b.write(change >= 0
          ? ' Naik $change% dibanding minggu lalu (${_num(lastKm)} km). Mantap!'
          : ' Turun ${-change}% dari minggu lalu (${_num(lastKm)} km). Masih ada waktu untuk mengejar.');
    }
    final bySport = <SportType, double>{};
    for (final a in week) {
      bySport[a.type] = (bySport[a.type] ?? 0) + a.km;
    }
    b.writeln('\n');
    for (final e in bySport.entries) {
      b.writeln('- ${e.key.label}: ${_num(e.value)} km');
    }
    if (_streak >= 2) b.write('\nKamu sedang dalam **streak $_streak hari**. Pertahankan!');
    return b.toString().trim();
  }

  String _goals() {
    if (goals.isEmpty) {
      return 'Kamu belum punya target. Buat target di menu **Profil > Target**, misalnya '
          '"lari ${_level == FitnessLevel.beginner ? 10 : 20} km per minggu". Target yang jelas bikin latihan lebih terarah.';
    }
    final b = StringBuffer('Progres targetmu:\n');
    for (final g in goals) {
      final p = g.progress(activities, now: now);
      final percent = (p.fraction * 100).round();
      if (p.completed) {
        b.writeln('- **${g.title}**: tercapai (${g.metric.format(p.current)} / ${g.targetLabel})');
        continue;
      }
      final daysLeft = p.to.difference(DateTime(now.year, now.month, now.day)).inDays.clamp(1, 31);
      b.writeln('- **${g.title}**: $percent% (${g.metric.format(p.current)} / ${g.targetLabel}). '
          'Kurang ${g.metric.format(p.remaining)} ${g.metric.unit} dalam $daysLeft hari, '
          'sekitar ${g.metric.format(p.remaining / daysLeft)} ${g.metric.unit} per hari.');
    }
    return b.toString().trim();
  }

  String _plan() {
    final sport = _mainSport;
    final sessions = switch (_level) {
      FitnessLevel.beginner => 3,
      FitnessLevel.intermediate => 4,
      FitnessLevel.advanced => 5,
    };
    final trainingDays = switch (sessions) {
      3 => [0, 2, 5],
      4 => [0, 2, 4, 6],
      _ => [0, 1, 3, 4, 6],
    };

    // Volume minggu depan: rata-rata 4 minggu terakhir untuk olahraga ini + 10%, minimal sesuai level
    final from = startOfWeek(now).subtract(const Duration(days: 28));
    final recent = _between(from, startOfWeek(now)).where((a) => a.type == sport);
    final minimum = switch (sport) {
      SportType.ride => sessions * 10.0,
      SportType.swim => sessions * 0.5,
      _ => sessions * (_level == FitnessLevel.beginner ? 2.0 : 4.0),
    };
    final weekly = (_km(recent) / 4 * 1.1).clamp(minimum, 200.0);
    final easy = weekly / (sessions + 0.5);
    final long = easy * 1.5;

    final b = StringBuffer('Rencana ${sport.label.toLowerCase()} minggu depan untuk level **${_level.label}** '
        '(total sekitar **${_num(weekly)} km**):\n');
    for (var d = 0; d < 7; d++) {
      final index = trainingDays.indexOf(d);
      if (index < 0) {
        b.writeln('- ${_days[d]}: istirahat atau jalan santai');
      } else if (index == trainingDays.length - 1) {
        b.writeln('- ${_days[d]}: **sesi panjang ${_num(long)} km**, tempo santai');
      } else if (index == 1 && sessions >= 4) {
        b.writeln('- ${_days[d]}: ${_num(easy)} km dengan interval (1 menit cepat, 2 menit santai)');
      } else {
        b.writeln('- ${_days[d]}: ${_num(easy)} km tempo nyaman');
      }
    }
    b.write('\nMasih bisa mengobrol saat latihan berarti tempomu sudah pas. Naikkan volume maksimal sekitar 10% per minggu.');
    return b.toString();
  }

  String _records() {
    if (activities.isEmpty) return 'Belum ada rekor karena belum ada aktivitas. Ayo catat latihan pertamamu!';
    final b = StringBuffer('Rekor pribadimu:\n');
    for (final type in SportType.values) {
      final list = activities.where((a) => a.type == type).toList();
      if (list.isEmpty) continue;
      final longest = list.reduce((a, b) => a.km >= b.km ? a : b);
      final eligible = list.where((a) => a.km >= 1).toList();
      b.write('- **${type.label}**: terjauh ${formatKm(longest.distanceMeters)} km (${formatDate(longest.startTime)})');
      if (eligible.isNotEmpty) {
        final fastest = eligible.reduce((a, b) => a.speedKmh >= b.speedKmh ? a : b);
        b.write(type.showsSpeed
            ? ', kecepatan terbaik ${formatSpeed(fastest.speedKmh)} km/j'
            : ', pace terbaik ${formatPace(fastest.paceSecPerKm)} /km');
      }
      b.writeln();
    }
    return b.toString().trim();
  }

  String _pace() {
    final runs = activities.where((a) => a.type == SportType.run && a.km >= 1).take(5).toList();
    final b = StringBuffer();
    if (runs.isNotEmpty) {
      final avg = _seconds(runs) / _km(runs);
      b.writeln('Rata-rata pace ${runs.length} lari terakhirmu **${formatPace(avg)} /km**. '
          'Target realistis bulan ini: **${formatPace(avg - 10)} /km**.\n');
    }
    b
      ..writeln('Tips meningkatkan pace:')
      ..writeln('- **80% latihan santai**: tetap dibutuhkan untuk membangun daya tahan')
      ..writeln('- **Interval** seminggu sekali: 6x400 m cepat, istirahat jalan 90 detik')
      ..writeln('- **Tempo run**: 20 menit di pace "agak berat tapi terkendali"')
      ..writeln('- Langkah pendek dan cepat (sekitar 170-180 langkah per menit) lebih efisien daripada langkah panjang')
      ..write('- Latihan kekuatan kaki 2x seminggu: squat, lunges, calf raise');
    return b.toString();
  }

  String _nutrition() => 'Panduan makan untuk latihan:\n'
      '- **1-3 jam sebelum**: karbohidrat mudah dicerna, misalnya roti, pisang, atau oatmeal\n'
      '- **Saat latihan > 60 menit**: minum tiap 15-20 menit, tambah elektrolit kalau berkeringat banyak\n'
      '- **30-60 menit sesudah**: kombinasi protein dan karbohidrat, misalnya nasi dengan telur atau susu cokelat\n'
      '- Cek hidrasi dari warna urine: kuning pucat berarti cukup\n\n'
      'Kebutuhan tiap orang berbeda; untuk diet khusus, konsultasikan dengan ahli gizi.';

  String _recovery() {
    final week = _thisWeek;
    final b = StringBuffer();
    if (week.length >= 5) {
      b.writeln('Kamu sudah ${week.length} sesi minggu ini, jadi istirahat itu wajib, bukan malas.\n');
    }
    b
      ..writeln('Kunci pemulihan:')
      ..writeln('- **Tidur 7-9 jam**: di sinilah otot diperbaiki')
      ..writeln('- Minimal **1-2 hari istirahat** per minggu, boleh diisi jalan santai atau peregangan')
      ..writeln('- Pegal 1-2 hari setelah latihan berat itu wajar; nyeri tajam atau bengkak tidak')
      ..write('- Gerakan ringan (jalan, foam roller) mempercepat pulih dibanding diam total');
    return b.toString();
  }

  String _warmUp() => 'Rutinitas singkat:\n'
      '- **Pemanasan 5-10 menit**: jalan cepat, leg swing, high knees, butt kicks, putar pinggul\n'
      '- Mulai latihan inti dengan tempo pelan selama beberapa menit pertama\n'
      '- **Pendinginan 5 menit**: jalan santai, lalu peregangan statis betis, paha depan, paha belakang, '
      'dan pinggul masing-masing 20-30 detik\n\n'
      'Peregangan statis paling baik dilakukan sesudah latihan, bukan sebelumnya.';

  String _motivation() {
    final total = _km(activities);
    final b = StringBuffer('Hari malas itu normal, $_firstName. ');
    if (total > 0) b.write('Kamu sudah menempuh **${_num(total)} km** sejak mulai memakai MoveUp. ');
    if (_streak >= 2) b.write('Streak-mu **$_streak hari**, sayang kalau putus! ');
    b.write('\n\nTrik yang ampuh:\n'
        '- **Aturan 10 menit**: janji ke diri sendiri bergerak 10 menit saja; biasanya kamu akan lanjut\n'
        '- Siapkan pakaian olahraga sejak malam sebelumnya\n'
        '- Ganti rute atau ajak teman supaya tidak bosan\n'
        '- Pasang pengingat latihan di menu **Profil > Pengaturan Reminder**');
    return b.toString();
  }

  String _bmi() {
    final p = profile;
    if (p == null) return 'Lengkapi profilmu dulu (berat dan tinggi badan) supaya aku bisa menghitung BMI-mu.';
    final b = StringBuffer('BMI-mu **${_num(p.bmi)}** (${p.bmiCategory}), dari berat ${_num(p.weightKg)} kg '
        'dan tinggi ${_num(p.heightCm)} cm.\n\n');
    b.write(switch (p.bmi) {
      < 18.5 => 'Fokus pada latihan kekuatan dan makan cukup protein serta kalori untuk menambah massa otot.',
      < 25 => 'Rentangmu sudah ideal. Pertahankan dengan latihan rutin dan pola makan seimbang.',
      _ => 'Kombinasikan kardio 150-300 menit per minggu dengan latihan kekuatan, dan kurangi kalori secara bertahap. '
          'Target aman: turun sekitar 0,5 kg per minggu.',
    });
    b.write('\n\nBMI hanya perkiraan kasar karena tidak membedakan otot dan lemak.');
    return b.toString();
  }

  String _safety() => 'Kalau kamu merasakan nyeri, pusing, sesak napas, atau nyeri dada, **hentikan latihan sekarang** '
      'dan istirahat. Untuk keluhan yang tidak membaik, terasa tajam, atau disertai bengkak, segera periksakan ke '
      'dokter atau fisioterapis.\n\n'
      'Aku bukan tenaga medis, jadi tidak bisa mendiagnosis. Setelah pulih, mulai lagi dengan intensitas rendah.';

  String _thanks() => 'Sama-sama, $_firstName! Semangat latihannya. Tanya lagi kapan saja.';

  String _greeting() {
    final week = _thisWeek;
    final status = week.isEmpty
        ? 'Minggu ini belum ada aktivitas, yuk mulai!'
        : 'Minggu ini kamu sudah ${week.length} aktivitas, ${_num(_km(week))} km.';
    return 'Halo, $_firstName! $status\n\nMau bahas apa hari ini?';
  }

  String _help() => 'Maaf, aku belum paham pertanyaan itu. Aku bisa membantu soal:\n'
      '- **Progres** latihan minggu ini\n'
      '- **Target** dan berapa yang masih kurang\n'
      '- **Rencana** latihan minggu depan\n'
      '- **Rekor** pribadi dan tips **pace**\n'
      '- **Makan**, **istirahat**, **pemanasan**, **motivasi**, dan **BMI**\n\n'
      'Coba tanyakan dengan salah satu kata di atas.';
}
