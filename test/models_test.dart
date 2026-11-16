import 'package:dracin_launcher/data/models.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Snapshot bolak-balik tanpa kehilangan data', () {
    const snap = Snapshot(
      dramas: [Drama(id: 'x', title: 'Judul', appPackage: 'com.wetv', appLabel: 'WeTV', episode: 7, days: {2, 5}, minuteOfDay: 1230, remind: false, leadMinutes: 30, lastWatchedMs: 99)],
      pinned: ['a', 'b'],
      settings: AppSettings(breakMinutes: 120, bedtimeEnabled: true, textSize: TextSize.large, themeMode: ThemeMode.light, onboarded: true),
    );
    final back = Snapshot.decode(snap.encode());
    final d = back.dramas.single;
    expect((d.id, d.title, d.appPackage, d.appLabel, d.episode, d.minuteOfDay, d.remind, d.leadMinutes, d.lastWatchedMs),
        ('x', 'Judul', 'com.wetv', 'WeTV', 7, 1230, false, 30, 99));
    expect(d.days, {2, 5});
    expect(back.pinned, ['a', 'b']);
    expect((back.settings.breakMinutes, back.settings.bedtimeEnabled, back.settings.textSize, back.settings.themeMode, back.settings.onboarded),
        (120, true, TextSize.large, ThemeMode.light, true));
  });

  test('data rusak tidak membuat aplikasi gagal', () {
    expect(Snapshot.decode('bukan json {').dramas, isEmpty);
    expect(Snapshot.decode(null).dramas, isEmpty);
    expect(Snapshot.decode('[]').dramas, isEmpty);
  });

  test('nilai di luar batas dirapikan', () {
    final d = Drama.fromJson({'id': 'a', 'title': 'T', 'days': [0, 3, 9, 'x'], 'minuteOfDay': 99999, 'episode': -4, 'leadMinutes': 5000});
    expect(d.days, {3});
    expect(d.minuteOfDay, 1439);
    expect(d.episode, 0);
    expect(d.leadMinutes, 120);
    expect(AppSettings.fromJson({'breakMinutes': 1, 'textSize': 'aneh'}).breakMinutes, 15);
    expect(AppSettings.fromJson({'textSize': 'aneh'}).textSize, TextSize.normal);
  });

  test('copyWith bisa mengosongkan aplikasi', () {
    const d = Drama(id: 'a', title: 'T', appPackage: 'p', appLabel: 'P');
    expect(d.copyWith(title: 'U').appPackage, 'p');
    expect(d.copyWith(appPackage: null, appLabel: null).appPackage, isNull);
  });
}
