import 'package:dracin_launcher/core/theme_pack.dart';
import 'package:dracin_launcher/data/app_state.dart';
import 'package:dracin_launcher/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

late DateTime clockNow;

Future<(AppState, FakeGateway, FakeScheduler)> make({Map<String, Object> prefs = const {}}) async {
  clockNow = DateTime(2026, 11, 16, 19, 30);
  SharedPreferences.setMockInitialValues(prefs);
  final gw = FakeGateway(apps: [
    AppEntry(package: 'com.tencent.qqlivei18n', label: 'WeTV', icon: kPng),
    AppEntry(package: 'com.iqiyi.i18n', label: 'iQIYI', icon: kPng),
    AppEntry(package: 'com.kalkulator', label: 'Kalkulator', icon: kPng),
  ]);
  final sch = FakeScheduler();
  final state = AppState(gateway: gw, scheduler: sch, prefs: await SharedPreferences.getInstance(), now: () => clockNow);
  await state.load();
  await state.refreshApps();
  return (state, gw, sch);
}

const cn = Drama(id: 'cn', title: 'Love Story', appPackage: 'com.tencent.qqlivei18n', episode: 3);
const kr = Drama(id: 'kr', title: 'Moonlight', appPackage: 'com.iqiyi.i18n', kind: ThemePackId.drakor, episode: 10);

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 450));

void main() {
  group('sesi menonton dan rekap', () {
    test('kembali setelah >= 1 menit memunculkan rekap; kurang dari itu diabaikan', () async {
      final (state, _, _) = await make();
      state.saveDrama(cn);
      await state.launchDrama(cn);
      clockNow = clockNow.add(const Duration(seconds: 20));
      state.onResumed();
      await Future<void>.delayed(Duration.zero);
      expect(state.pendingRecap.value, isNull);

      await state.launchDrama(cn);
      clockNow = clockNow.add(const Duration(minutes: 42));
      state.onResumed();
      await Future<void>.delayed(Duration.zero);
      final r = state.pendingRecap.value!;
      expect((r.dramaId, r.package, r.duration), ('cn', 'com.tencent.qqlivei18n', const Duration(minutes: 42)));
      await settle();
    });

    test('membuka WeTV langsung dari dock (tanpa drama) tetap tercatat sebagai sesi', () async {
      final (state, _, _) = await make();
      await state.launchPackage('com.tencent.qqlivei18n');
      clockNow = clockNow.add(const Duration(minutes: 10));
      state.onResumed();
      await Future<void>.delayed(Duration.zero);
      expect(state.pendingRecap.value!.dramaId, isNull);
      expect(state.pendingRecap.value!.package, 'com.tencent.qqlivei18n');
    });

    test('aplikasi biasa (bukan tontonan) tidak dicatat', () async {
      final (state, _, _) = await make();
      await state.launchPackage('com.kalkulator');
      clockNow = clockNow.add(const Duration(minutes: 10));
      state.onResumed();
      await Future<void>.delayed(Duration.zero);
      expect(state.pendingRecap.value, isNull);
    });

    test('selesai: riwayat bertambah, episode naik, terakhir ditonton diperbarui', () async {
      final (state, _, _) = await make();
      state.saveDrama(cn);
      await state.launchDrama(cn);
      clockNow = clockNow.add(const Duration(minutes: 42));
      state.onResumed();
      await Future<void>.delayed(Duration.zero);
      state.logWatch(state.pendingRecap.value!, drama: cn, completed: true);

      final h = state.history.single;
      expect((h.title, h.episode, h.completed, h.kind, h.durationSec), ('Love Story', 4, true, ThemePackId.dracin, 42 * 60));
      expect(state.dramas.single.episode, 4);
      expect(state.dramas.single.lastWatchedMs, greaterThan(0));
      expect(state.pendingRecap.value, isNull);
      await settle();
    });

    test('baru sebagian: episode tidak naik tetapi tetap tercatat dan jadi yang terakhir', () async {
      final (state, _, _) = await make();
      state.saveDrama(cn);
      state.saveDrama(kr);
      await state.launchDrama(cn);
      clockNow = clockNow.add(const Duration(minutes: 15));
      state.onResumed();
      await Future<void>.delayed(Duration.zero);
      state.logWatch(state.pendingRecap.value!, drama: cn, completed: false);
      expect(state.history.single.completed, isFalse);
      expect(state.history.single.episode, 4); // yang sedang ditonton
      expect(state.dramas.firstWhere((d) => d.id == 'cn').episode, 3);
      expect(state.dramasByRecent.first.id, 'cn');
      await settle();
    });

    test('tanpa drama: dicatat dengan nama aplikasi dan tanpa episode', () async {
      final (state, _, _) = await make();
      await state.launchPackage('com.iqiyi.i18n');
      clockNow = clockNow.add(const Duration(minutes: 5));
      state.onResumed();
      await Future<void>.delayed(Duration.zero);
      state.logWatch(state.pendingRecap.value!, drama: null, completed: true);
      final h = state.history.single;
      expect((h.title, h.episode, h.completed, h.dramaId), ('iQIYI', null, false, null));
    });

    test('dilewati: tidak ada yang tercatat', () async {
      final (state, _, _) = await make();
      state.saveDrama(cn);
      await state.launchDrama(cn);
      clockNow = clockNow.add(const Duration(minutes: 5));
      state.onResumed();
      await Future<void>.delayed(Duration.zero);
      state.skipRecap();
      expect(state.history, isEmpty);
      expect(state.pendingRecap.value, isNull);
      await settle();
    });
  });

  group('riwayat', () {
    test('tersimpan, dimuat ulang, dibatasi 300, bisa dihapus per entri atau semua', () async {
      final (state, _, _) = await make();
      for (var i = 0; i < 305; i++) {
        state.logWatch(
          Recap(package: 'com.iqiyi.i18n', startedAt: clockNow.add(Duration(minutes: i)), duration: const Duration(minutes: 2)),
          drama: null,
          completed: false,
        );
      }
      expect(state.history, hasLength(300));
      expect(state.history.first.startMs, clockNow.add(const Duration(minutes: 304)).millisecondsSinceEpoch);

      final again = AppState(gateway: FakeGateway(), scheduler: FakeScheduler(), prefs: await SharedPreferences.getInstance());
      await again.load();
      expect(again.history, hasLength(300));

      state.removeHistory(state.history.first.id);
      expect(state.history, hasLength(299));
      state.clearHistory();
      expect(state.history, isEmpty);
    });

    test('waktu menonton per jenis dalam 7 hari', () async {
      final (state, _, _) = await make();
      void log(Drama d, DateTime at, int min) =>
          state.logWatch(Recap(package: 'x', startedAt: at, duration: Duration(minutes: min)), drama: d, completed: false);
      log(cn, clockNow.subtract(const Duration(days: 1)), 60);
      log(kr, clockNow.subtract(const Duration(days: 2)), 90);
      log(kr, clockNow.subtract(const Duration(days: 3)), 30);
      log(cn, clockNow.subtract(const Duration(days: 20)), 500); // di luar jendela
      final t = state.watchTime(clockNow.subtract(const Duration(days: 7)));
      expect(t[ThemePackId.dracin], const Duration(minutes: 60));
      expect(t[ThemePackId.drakor], const Duration(minutes: 120));
      await settle();
    });
  });

  group('mode Dracin / Drakor', () {
    test('mode menyaring drama dan memasang paket tema yang sama; "Semua" tidak mengubah tema', () async {
      final (state, _, _) = await make();
      state.saveDrama(cn);
      state.saveDrama(kr);
      expect(state.visibleDramas.map((d) => d.id).toSet(), {'cn', 'kr'});

      state.setMode(ViewMode.drakor);
      expect(state.visibleDramas.map((d) => d.id), ['kr']);
      expect(state.settings.themePack, ThemePackId.drakor);
      expect(state.appearance.value.$3, ThemePackId.drakor);

      state.setMode(ViewMode.all);
      expect(state.visibleDramas, hasLength(2));
      expect(state.settings.themePack, ThemePackId.drakor); // tema tidak diubah
      await settle();
    });

    test('membuka drama jenis lain saat mode terkunci memindahkan mode; mode Semua tetap', () async {
      final (state, _, _) = await make();
      state.saveDrama(cn);
      state.saveDrama(kr);
      state.setMode(ViewMode.dracin);
      await state.launchDrama(kr);
      expect(state.settings.viewMode, ViewMode.drakor);
      expect(state.settings.themePack, ThemePackId.drakor);

      state.setMode(ViewMode.all);
      await state.launchDrama(cn);
      expect(state.settings.viewMode, ViewMode.all);
      await settle();
    });

    test('jenis drama dan mode tersimpan', () async {
      final back = Drama.fromJson(kr.toJson());
      expect(back.kind, ThemePackId.drakor);
      expect(Drama.fromJson({'id': 'a', 'title': 'T', 'kind': 'aneh'}).kind, ThemePackId.dracin);
      final s = AppSettings.fromJson(const AppSettings(viewMode: ViewMode.drakor).toJson());
      expect(s.viewMode, ViewMode.drakor);
    });
  });

  group('catat otomatis dari judul yang terbaca', () {
    test('judul cocok dengan drama: dicatat otomatis dengan gambar kecil, tanpa lembar rekap', () async {
      final (state, gw, _) = await make();
      state.saveDrama(cn);
      await state.launchDrama(cn);
      gw.seen = const NowWatchingInfo(package: 'com.tencent.qqlivei18n', title: 'love  STORY', thumb: '/data/thumbs/a.jpg');
      clockNow = clockNow.add(const Duration(minutes: 30));
      state.onResumed();
      await Future<void>.delayed(Duration.zero);

      expect(state.pendingRecap.value, isNull);
      final h = state.history.single;
      expect((h.title, h.dramaId, h.auto, h.thumb, h.durationSec), ('Love Story', 'cn', true, '/data/thumbs/a.jpg', 30 * 60));
      expect(state.autoLogged.value!.entry.id, h.id);
      expect(gw.clearedSeen, 1);
      await settle();
    });

    test('judul tidak dikenal: tetap dicatat dengan judul terbaca dari layar', () async {
      final (state, gw, _) = await make();
      await state.launchPackage('com.iqiyi.i18n');
      gw.seen = const NowWatchingInfo(package: 'com.iqiyi.i18n', title: 'Overdo', thumb: null);
      clockNow = clockNow.add(const Duration(minutes: 12));
      state.onResumed();
      await Future<void>.delayed(Duration.zero);
      final h = state.history.single;
      expect((h.title, h.dramaId, h.auto, h.thumb), ('Overdo', null, true, null));
    });

    test('judul dari aplikasi lain atau pengaturan mati: kembali ke pertanyaan "Tadi nonton apa?"', () async {
      final (state, gw, _) = await make();
      await state.launchPackage('com.iqiyi.i18n');
      gw.seen = const NowWatchingInfo(package: 'com.tencent.qqlivei18n', title: 'Sisa dari WeTV', thumb: null);
      clockNow = clockNow.add(const Duration(minutes: 12));
      state.onResumed();
      await Future<void>.delayed(Duration.zero);
      expect(state.history, isEmpty);
      expect(state.pendingRecap.value, isNotNull);

      state.skipRecap();
      state.updateSettings(state.settings.copyWith(autoLog: false));
      gw.seen = const NowWatchingInfo(package: 'com.iqiyi.i18n', title: 'Overdo', thumb: null);
      await state.launchPackage('com.iqiyi.i18n');
      clockNow = clockNow.add(const Duration(minutes: 12));
      state.onResumed();
      await Future<void>.delayed(Duration.zero);
      expect(state.history, isEmpty);
      expect(state.pendingRecap.value, isNotNull);
    });

    test('titlesMatch: abaikan huruf besar dan tanda baca; potongan pendek tidak cocok sembarangan', () {
      expect(titlesMatch('Love Between Fairy & Devil', 'love between fairy and devil'), isFalse); // & vs and: berbeda
      expect(titlesMatch('UNSEEN (Uncut Ver.)', 'Unseen'), isTrue);
      expect(titlesMatch('Overdo', 'overdo!'), isTrue);
      expect(titlesMatch('Love', 'Love Story'), isFalse); // terlalu pendek untuk "memuat"
      expect(titlesMatch('', 'x'), isFalse);
    });

    test('catatan menyimpan gambar kecil dan penanda otomatis', () {
      const e = WatchEntry(id: 'w', title: 'T', kind: ThemePackId.drakor, startMs: 1, durationSec: 60, thumb: '/t.jpg', auto: true);
      final back = WatchEntry.fromJson(e.toJson());
      expect((back.thumb, back.auto), ('/t.jpg', true));
      expect(AppSettings.fromJson(const AppSettings(autoLog: false).toJson()).autoLog, isFalse);
      expect(AppSettings.fromJson(const {}).autoLog, isTrue);
    });
  });
}
