const weekdayLong = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const weekdayShort = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const monthLong = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

/// Hari dalam gaya DateTime.weekday: 1 = Senin ... 7 = Minggu.
String dayLong(int weekday) => weekdayLong[weekday - 1];
String dayShort(int weekday) => weekdayShort[weekday - 1];

String two(int v) => v.toString().padLeft(2, '0');

/// 20.30 (gaya Indonesia).
String clock(int minuteOfDay) => '${two(minuteOfDay ~/ 60)}.${two(minuteOfDay % 60)}';

String dateLong(DateTime d) => '${dayLong(d.weekday)}, ${d.day} ${monthLong[d.month - 1]} ${d.year}';

String greeting(int hour) {
  if (hour < 4) return 'Selamat malam';
  if (hour < 11) return 'Selamat pagi';
  if (hour < 15) return 'Selamat siang';
  if (hour < 18) return 'Selamat sore';
  return 'Selamat malam';
}

/// Ringkas: "Setiap hari", "Sen, Kam", "Sabtu".
String daysSummary(Set<int> days) {
  if (days.isEmpty) return 'Tanpa jadwal';
  if (days.length == 7) return 'Setiap hari';
  final sorted = days.toList()..sort();
  if (sorted.length == 1) return dayLong(sorted.first);
  return sorted.map(dayShort).join(', ');
}

/// "hari ini", "besok", atau nama hari, untuk [when] relatif terhadap [now].
String relativeDay(DateTime when, DateTime now) {
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(when.year, when.month, when.day);
  final diff = b.difference(a).inDays;
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Besok';
  return dayLong(when.weekday);
}

/// "dalam 35 menit", "dalam 2 jam 10 menit", atau kosong bila lebih dari sehari.
String untilText(Duration d) {
  final m = d.inMinutes;
  if (m < 1) return 'sebentar lagi';
  if (m < 60) return 'dalam $m menit';
  if (m < 24 * 60) {
    final h = m ~/ 60, r = m % 60;
    return r == 0 ? 'dalam $h jam' : 'dalam $h jam $r menit';
  }
  return '';
}

/// "baru saja", "5 menit lalu", "2 jam lalu".
String agoText(Duration d) {
  final m = d.inMinutes;
  if (m < 1) return 'baru saja';
  if (m < 60) return '$m menit lalu';
  return '${d.inHours} jam lalu';
}

/// Ukuran memori gaya Indonesia: "312 MB", "2,1 GB".
String bytesText(int bytes) {
  final abs = bytes.abs();
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  final sign = bytes < 0 ? '-' : '';
  if (abs >= gb) return '$sign${(abs / gb).toStringAsFixed(1).replaceAll('.', ',')} GB';
  return '$sign${(abs / mb).round()} MB';
}

/// "25 menit", "1 jam 12 menit", "2 jam".
String durationText(Duration d) {
  final m = d.inMinutes;
  if (m < 1) return 'kurang dari semenit';
  if (m < 60) return '$m menit';
  final h = m ~/ 60, r = m % 60;
  return r == 0 ? '$h jam' : '$h jam $r menit';
}

/// "Hari ini", "Kemarin", atau "Sabtu, 14 November" untuk pengelompokan riwayat.
String dayHeading(DateTime when, DateTime now) {
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(when.year, when.month, when.day);
  final diff = a.difference(b).inDays;
  if (diff == 0) return 'Hari ini';
  if (diff == 1) return 'Kemarin';
  return '${dayLong(when.weekday)}, ${when.day} ${monthLong[when.month - 1]}';
}
