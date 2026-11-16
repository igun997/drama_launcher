import 'package:dracin_launcher/alerts/scheduler.dart';
import 'package:dracin_launcher/data/app_state.dart';
import 'package:dracin_launcher/data/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

Future<(AppState, FakeGateway, FakeScheduler)> make({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final gw = FakeGateway();
  final sch = FakeScheduler();
  final state = AppState(
    gateway: gw,
    scheduler: sch,
    prefs: await SharedPreferences.getInstance(),
    now: () => DateTime(2026, 11, 16, 19, 30),
  );
  await state.load();
  await state.refreshApps();
  return (state, gw, sch);
}

const wetv = Drama(id: 'a', title: 'Love Story', appPackage: 'com.wetv', appLabel: 'WeTV', days: {1}, episode: 3);

void main() {
  test('membuka aplikasi drama memulai pengingat istirahat; kembali ke launcher membatalkan', () async {
    final (state, gw, sch) = await make();
    state.saveDrama(wetv);
    expect(await state.launchDrama(wetv), isTrue);
    expect(gw.launched, ['com.wetv']);
    expect(sch.breaks.single.minutes, 90);
    expect(state.watching, isTrue);
    state.onResumed();
    await Future<void>.delayed(Duration.zero);
    expect(state.watching, isFalse);
    expect(sch.cancelBreaks, 1);
  });

  test('aplikasi biasa atau pengaturan mati tidak memasang pengingat istirahat', () async {
    final (state, _, sch) = await make();
    state.saveDrama(wetv);
    await state.launchPackage('com.whatsapp');
    expect(sch.breaks, isEmpty);
    state.updateSettings(state.settings.copyWith(breakEnabled: false));
    await state.launchDrama(wetv);
    expect(sch.breaks, isEmpty);
  });

  test('gagal membuka aplikasi tidak memulai sesi', () async {
    final (state, gw, sch) = await make();
    state.saveDrama(wetv);
    gw.launchResult = false;
    expect(await state.launchDrama(wetv), isFalse);
    expect(sch.breaks, isEmpty);
    expect(state.watching, isFalse);
  });

  test('mematikan istirahat saat sesi berjalan membatalkan pengingat', () async {
    final (state, _, sch) = await make();
    state.saveDrama(wetv);
    await state.launchDrama(wetv);
    state.updateSettings(state.settings.copyWith(breakEnabled: false));
    expect(sch.cancelBreaks, 1);
  });

  test('episode bertambah, urungkan memulihkan, urutan terakhir ditonton di depan', () async {
    final (state, _, _) = await make();
    state.saveDrama(wetv);
    state.saveDrama(const Drama(id: 'b', title: 'Lain', days: {2}));
    final before = state.bumpEpisode('b', 1);
    expect(before, 0);
    expect(state.dramas.firstWhere((d) => d.id == 'b').episode, 1);
    expect(state.dramasByRecent.first.id, 'b');
    state.setEpisode('b', before);
    expect(state.dramas.firstWhere((d) => d.id == 'b').episode, 0);
  });

  test('perubahan disimpan dan dimuat ulang; pengingat dipasang ulang setelah jeda singkat', () async {
    final (state, _, sch) = await make();
    state.saveDrama(wetv);
    state.togglePin('com.wetv');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(sch.lastPlan, hasLength(1));
    expect(sch.lastPlan.single.weekday, 1);

    final prefs = await SharedPreferences.getInstance();
    final again = AppState(gateway: FakeGateway(), scheduler: FakeScheduler(), prefs: prefs);
    await again.load();
    expect(again.dramas.single.title, 'Love Story');
    expect(again.pinned, ['com.wetv']);
  });

  test('pintasan maksimal 6 dan aplikasi yang dihapus dibersihkan', () async {
    final (state, gw, _) = await make();
    for (final p in ['a', 'b', 'c', 'd', 'e', 'f', 'g']) {
      state.togglePin(p);
    }
    expect(state.pinned, ['a', 'b', 'c', 'd', 'e', 'f']);
    expect(state.pinsFull, isTrue);
    gw.packagesCb!();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(state.pinned, isEmpty); // tidak satu pun terpasang di FakeGateway
  });

  test('dock: aplikasi tontonan unik dulu, lalu pintasan tanpa duplikat', () async {
    final (state, _, _) = await make();
    state.saveDrama(wetv);
    state.saveDrama(const Drama(id: 'b', title: 'Lain', appPackage: 'com.wetv', appLabel: 'WeTV'));
    state.togglePin('com.wetv');
    expect(state.dockApps.map((a) => a.package), ['com.wetv']);
    expect(state.isWatchApp('com.wetv'), isTrue);
    expect(state.isWatchApp('com.lain'), isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 450));
  });

  test('ketuk notifikasi drama membuka drama yang benar', () async {
    final (state, _, sch) = await make();
    state.saveDrama(wetv);
    sch.payload = 'drama:a';
    Drama? opened;
    await state.warmUp(onOpenFromNotification: (d) => opened = d);
    expect(opened?.id, 'a');
    expect(sch.lastPlan, isNotEmpty);
  });

  test('pengingat gagal disiapkan: dilaporkan, beranda dan daftar aplikasi tetap jalan', () async {
    final (state, _, sch) = await make();
    sch.initFails = true;
    final reported = <FlutterErrorDetails>[];
    final old = FlutterError.onError;
    FlutterError.onError = reported.add;
    try {
      await state.warmUp(onOpenFromNotification: (_) {});
    } finally {
      FlutterError.onError = old;
    }
    expect(reported, hasLength(1));
    expect(state.apps, isNotEmpty);
  });

  test('izin alarm tepat waktu baru diberikan: pengingat dipasang ulang', () async {
    final (state, _, sch) = await make();
    state.saveDrama(wetv);
    sch.perms = const AlertPermissions(notifications: true, exactAlarms: false);
    await state.refreshPermissions();
    final before = sch.syncCount;
    await state.refreshPermissions(); // tidak berubah: tidak perlu pasang ulang
    expect(sch.syncCount, before);
    sch.perms = const AlertPermissions(notifications: true, exactAlarms: true);
    await state.refreshPermissions();
    expect(sch.syncCount, before + 1);
    await Future<void>.delayed(const Duration(milliseconds: 450));
  });
}
