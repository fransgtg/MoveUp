import 'package:moveup/models/activity.dart';

const monthNames = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
const _monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
const dayInitials = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

String _two(int n) => n.toString().padLeft(2, '0');

// 1:05:09 atau 32:15
String formatDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(s)}' : '$m:${_two(s)}';
}

// 1j 5m atau 32m
String formatDurationShort(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '${h}j ${m}m';
  if (m > 0) return '${m}m';
  return '${seconds}d';
}

String formatKm(double meters, {int decimals = 2}) =>
    (meters / 1000).toStringAsFixed(decimals).replaceAll('.', ',');

String formatPace(double? secPerKm) {
  if (secPerKm == null || !secPerKm.isFinite) return '-:--';
  final total = secPerKm.round();
  return '${total ~/ 60}:${_two(total % 60)}';
}

String formatSpeed(double kmh) => kmh.toStringAsFixed(1).replaceAll('.', ',');

// Label dan nilai pace/kecepatan sesuai jenis olahraga
(String, String) paceOrSpeed(Activity a) => a.type.showsSpeed
    ? ('Kecepatan', '${formatSpeed(a.speedKmh)} km/j')
    : ('Pace', '${formatPace(a.paceSecPerKm)} /km');

String formatDate(DateTime d) => '${d.day} ${_monthShort[d.month - 1]} ${d.year}';

String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

String formatRelativeDateTime(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  final prefix = switch (diff) {
    0 => 'Hari ini',
    1 => 'Kemarin',
    _ => formatDate(d),
  };
  return '$prefix pukul ${formatTime(d)}';
}

// Pemisah tanggal di ruang chat: Hari ini, Kemarin, atau 12 Okt 2026
String formatChatDay(DateTime d) {
  final now = DateTime.now();
  final diff = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  return switch (diff) {
    0 => 'Hari ini',
    1 => 'Kemarin',
    _ => formatDate(d),
  };
}

// Waktu di daftar percakapan: jam untuk hari ini, selain itu tanggal
String formatChatTime(DateTime d) {
  final label = formatChatDay(d);
  return label == 'Hari ini' ? formatTime(d) : label;
}

// Judul otomatis seperti "Lari Pagi" atau "Bersepeda Sore"
String defaultTitle(SportType type, DateTime start) {
  final h = start.hour;
  final time = h < 11 ? 'Pagi' : h < 15 ? 'Siang' : h < 18 ? 'Sore' : 'Malam';
  final sport = type == SportType.ride ? 'Bersepeda' : type.label;
  return '$sport $time';
}

DateTime startOfWeek(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
