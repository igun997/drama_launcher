import '../core/format.dart';
import '../data/models.dart';

/// Satu pengingat berulang yang harus dipasang di Android.
class PlannedAlert {
  const PlannedAlert({
    required this.id,
    required this.channel,
    required this.title,
    required this.body,
    required this.minuteOfDay,
    this.weekday,
    this.payload,
  });

  final int id;
  final AlertChannel channel;
  final String title;
  final String body;

  /// 1..7 (Senin..Minggu) untuk mingguan, null untuk harian.
  final int? weekday;
  final int minuteOfDay;
  final String? payload;

  @override
  bool operator ==(Object other) =>
      other is PlannedAlert &&
      other.id == id &&
      other.channel == channel &&
      other.title == title &&
      other.body == body &&
      other.weekday == weekday &&
      other.minuteOfDay == minuteOfDay &&
      other.payload == payload;

  @override
  int get hashCode => Object.hash(id, channel, title, body, weekday, minuteOfDay, payload);

  @override
  String toString() => 'PlannedAlert($id ${channel.name} wd=$weekday ${clock(minuteOfDay)} "$title")';
}

enum AlertChannel { tayang, istirahat, tidur }

/// ID tetap untuk pengingat istirahat sekali-jalan dan jam tidur.
const int kBreakAlertId = 2;
const int kBedtimeAlertId = 3;

/// ID pengingat drama: stabil antar peluncuran (FNV-1a, bukan String.hashCode).
int dramaAlertId(String dramaId, int weekday) {
  var h = 0x811C9DC5;
  for (final u in dramaId.codeUnits) {
    h ^= u;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return ((h % 100000) + 1) * 10 + weekday + 100; // selalu > 100, tidak menabrak id tetap
}

String episodeText(Drama d) => 'Eps ${d.nextEpisode}';

/// Isi notifikasi saat jam tayang tiba.
String dramaBody(Drama d) {
  final where = d.appLabel == null ? '' : ' di ${d.appLabel}';
  if (d.leadMinutes > 0) {
    return '${episodeText(d)} tayang ${d.leadMinutes} menit lagi (jam ${clock(d.minuteOfDay)})$where. Siapkan camilannya!';
  }
  return '${episodeText(d)} tayang sekarang$where.';
}

/// Rencana pengingat berulang dari data pengguna. Murni, tanpa efek samping.
List<PlannedAlert> planAlerts(List<Drama> dramas, AppSettings settings) {
  final out = <PlannedAlert>[];
  for (final d in dramas) {
    if (!d.remind || d.days.isEmpty) continue;
    for (final day in d.days) {
      var minute = d.minuteOfDay - d.leadMinutes;
      var weekday = day;
      if (minute < 0) {
        minute += 1440;
        weekday = weekday == 1 ? 7 : weekday - 1;
      }
      out.add(PlannedAlert(
        id: dramaAlertId(d.id, day),
        channel: AlertChannel.tayang,
        title: d.title,
        body: dramaBody(d),
        weekday: weekday,
        minuteOfDay: minute,
        payload: 'drama:${d.id}',
      ));
    }
  }
  if (settings.bedtimeEnabled) {
    out.add(PlannedAlert(
      id: kBedtimeAlertId,
      channel: AlertChannel.tidur,
      title: 'Sudah malam',
      body: 'Sudah jam ${clock(settings.bedtimeMinute)}. Lanjutkan besok ya, matanya perlu istirahat.',
      minuteOfDay: settings.bedtimeMinute,
    ));
  }
  return out;
}

/// Tayang berikutnya dari satu drama (jam tayang, bukan jam pengingat) pada atau setelah [now].
DateTime? nextAiring(Drama d, DateTime now) {
  if (d.days.isEmpty) return null;
  DateTime? best;
  for (final day in d.days) {
    var add = (day - now.weekday) % 7;
    var t = DateTime(now.year, now.month, now.day + add, d.minuteOfDay ~/ 60, d.minuteOfDay % 60);
    if (t.isBefore(now)) t = DateTime(t.year, t.month, t.day + 7, t.hour, t.minute);
    if (best == null || t.isBefore(best)) best = t;
  }
  return best;
}

class NextUp {
  const NextUp(this.drama, this.when);
  final Drama drama;
  final DateTime when;
}

/// Drama yang tayang paling dekat dari sekarang (null bila tidak ada jadwal).
NextUp? nextUp(List<Drama> dramas, DateTime now) {
  NextUp? best;
  for (final d in dramas) {
    final t = nextAiring(d, now);
    if (t != null && (best == null || t.isBefore(best.when))) best = NextUp(d, t);
  }
  return best;
}

/// Drama yang tayang hari ini dan jamnya belum lewat lebih dari 3 jam, urut jam.
List<Drama> airingToday(List<Drama> dramas, DateTime now) {
  final nowMin = now.hour * 60 + now.minute;
  final list = dramas.where((d) => d.days.contains(now.weekday) && nowMin - d.minuteOfDay <= 180).toList()
    ..sort((a, b) => a.minuteOfDay.compareTo(b.minuteOfDay));
  return list;
}
