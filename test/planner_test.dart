import 'package:dracin_launcher/alerts/planner.dart';
import 'package:dracin_launcher/data/models.dart';
import 'package:flutter_test/flutter_test.dart';

Drama drama({Set<int> days = const {1, 4}, int minute = 20 * 60, int lead = 10, bool remind = true, String id = 'a', int ep = 23}) =>
    Drama(id: id, title: 'Love Story', appLabel: 'WeTV', episode: ep, days: days, minuteOfDay: minute, leadMinutes: lead, remind: remind);

void main() {
  group('planAlerts', () {
    test('satu alert mingguan per hari, lebih awal sesuai jeda', () {
      final plan = planAlerts([drama()], const AppSettings());
      expect(plan.map((a) => (a.weekday, a.minuteOfDay)).toSet(), {(1, 19 * 60 + 50), (4, 19 * 60 + 50)});
      expect(plan.first.body, contains('Eps 24'));
      expect(plan.first.body, contains('10 menit lagi'));
      expect(plan.first.payload, 'drama:a');
    });

    test('jeda melewati tengah malam mundur ke hari sebelumnya', () {
      final plan = planAlerts([drama(days: {1, 3}, minute: 5, lead: 10)], const AppSettings());
      expect(plan.map((a) => (a.weekday, a.minuteOfDay)).toSet(), {(7, 1435), (2, 1435)});
    });

    test('tanpa jadwal atau pengingat mati tidak menghasilkan alert', () {
      expect(planAlerts([drama(days: {})], const AppSettings()), isEmpty);
      expect(planAlerts([drama(remind: false)], const AppSettings()), isEmpty);
    });

    test('jam tidur menambah alert harian', () {
      final plan = planAlerts(const [], const AppSettings(bedtimeEnabled: true, bedtimeMinute: 22 * 60 + 30));
      expect(plan, hasLength(1));
      expect(plan.single.weekday, isNull);
      expect(plan.single.id, kBedtimeAlertId);
      expect(plan.single.body, contains('22.30'));
    });

    test('id stabil, unik per drama dan hari, tidak menabrak id tetap', () {
      final plan = planAlerts([drama(days: {1, 2, 3, 4, 5, 6, 7}), drama(id: 'b', days: {1, 2, 3, 4, 5, 6, 7})], const AppSettings());
      final ids = plan.map((a) => a.id).toList();
      expect(ids.toSet(), hasLength(14));
      expect(ids.every((i) => i > 100), isTrue);
      expect(dramaAlertId('a', 1), dramaAlertId('a', 1));
    });
  });

  group('nextAiring', () {
    // 16 Nov 2026 = Senin
    final monday1930 = DateTime(2026, 11, 16, 19, 30);

    test('hari ini bila jamnya belum lewat', () {
      expect(nextAiring(drama(days: {1}), monday1930), DateTime(2026, 11, 16, 20));
    });

    test('pekan depan bila jamnya sudah lewat', () {
      expect(nextAiring(drama(days: {1}), DateTime(2026, 11, 16, 20, 1)), DateTime(2026, 11, 23, 20));
    });

    test('memilih hari terdekat, melewati batas bulan', () {
      expect(nextAiring(drama(days: {3, 6}), DateTime(2026, 11, 28, 21)), DateTime(2026, 12, 2, 20));
    });

    test('tanpa jadwal -> null; nextUp memilih tayang paling dekat', () {
      expect(nextAiring(drama(days: {}), monday1930), isNull);
      final a = drama(id: 'a', days: {5});
      final b = drama(id: 'b', days: {2});
      expect(nextUp([a, b], monday1930)!.drama.id, 'b');
    });
  });

  test('airingToday: hari ini, urut jam, maksimal 3 jam setelah tayang', () {
    final monday2200 = DateTime(2026, 11, 16, 22);
    final early = drama(id: 'e', days: {1}, minute: 19 * 60 + 30);
    final late = drama(id: 'l', days: {1}, minute: 21 * 60);
    final long = drama(id: 'x', days: {1}, minute: 17 * 60);
    final other = drama(id: 'o', days: {2});
    expect(airingToday([late, early, long, other], monday2200).map((d) => d.id), ['e', 'l']);
  });
}
