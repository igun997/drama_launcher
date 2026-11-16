import 'package:dracin_launcher/data/app_state.dart';
import 'package:dracin_launcher/data/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

final t0 = DateTime(2026, 11, 16, 19, 30);

Future<(AppState, FakeGateway)> make({bool access = true}) async {
  SharedPreferences.setMockInitialValues({});
  final gw = FakeGateway(apps: [
    AppEntry(package: 'com.wetv', label: 'WeTV', icon: kPng),
    AppEntry(package: 'com.viu', label: 'Viu', icon: kPng),
    AppEntry(package: 'com.chat', label: 'Chat', icon: kPng),
    AppEntry(package: 'com.android.settings', label: 'Pengaturan', icon: kPng),
  ]);
  gw.usageAccess = access;
  gw.usage = [
    ActiveUsage(package: 'com.wetv', lastUsedMs: t0.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch, foreground: false),
    ActiveUsage(package: 'com.chat', lastUsedMs: t0.subtract(const Duration(minutes: 1)).millisecondsSinceEpoch, foreground: true),
    ActiveUsage(package: 'com.tidak.terpasang', lastUsedMs: t0.millisecondsSinceEpoch, foreground: false),
  ];
  final state = AppState(gateway: gw, scheduler: FakeScheduler(), prefs: await SharedPreferences.getInstance(), now: () => t0);
  await state.load();
  await state.refreshApps();
  return (state, gw);
}

void main() {
  test('daftar aktif: hanya aplikasi yang dikenal launcher, urutan dari Android dipertahankan', () async {
    final (state, _) = await make();
    await state.refreshActive();
    expect(state.activeApps.map((a) => a.app.package), ['com.wetv', 'com.chat']);
    expect(state.activeApps.last.foreground, isTrue);
    expect(state.activeCount, 2);
    expect(state.ram.total, greaterThan(0));
  });

  test('Pengaturan tidak ditampilkan sebagai aplikasi aktif (dibuka oleh layanan tutup aplikasi sendiri)', () async {
    final (state, gw) = await make();
    gw.usage = [
      ActiveUsage(package: 'com.android.settings', lastUsedMs: t0.millisecondsSinceEpoch, foreground: false),
      ...gw.usage,
    ];
    await state.refreshApps();
    await state.refreshActive();
    expect(state.activeApps.map((a) => a.app.package), isNot(contains('com.android.settings')));
  });

  test('tanpa akses penggunaan daftar kosong tetapi RAM tetap terbaca', () async {
    final (state, gw) = await make(access: false);
    await state.refreshActive();
    expect(state.hasUsageAccess, isFalse);
    expect(state.activeApps, isEmpty);
    expect(state.ram.total, gw.ram.total);
  });

  test('tutup aplikasi: dihentikan paksa dan hilang dari daftar sampai dipakai lagi', () async {
    final (state, gw) = await make();
    await state.refreshActive();
    final r = await state.closeApp('com.wetv');
    expect(r, isNotNull);
    expect(gw.stopped, [['com.wetv']]);
    expect(state.activeApps.map((a) => a.app.package), ['com.chat']);
    await state.refreshActive(); // pemakaian lama tidak membangkitkannya lagi
    expect(state.activeApps.map((a) => a.app.package), ['com.chat']);

    gw.usage = [ActiveUsage(package: 'com.wetv', lastUsedMs: t0.add(const Duration(minutes: 3)).millisecondsSinceEpoch, foreground: false)];
    await state.refreshActive(); // dipakai lagi setelah ditutup: muncul kembali
    expect(state.activeApps.single.app.package, 'com.wetv');
  });

  test('bersihkan RAM: menutup yang di latar saja, tidak yang sedang tampil', () async {
    final (state, gw) = await make();
    await state.refreshActive();
    final before = state.ram.avail;
    final r = await state.cleanRam();
    expect(gw.stopped, [['com.wetv']]);
    expect(r!.closed, 1);
    expect(r.freed, 300 * 1024 * 1024);
    expect(state.ram.avail, before + 300 * 1024 * 1024);
    expect(state.activeApps.map((a) => a.app.package), ['com.chat']);
  });

  test('gagal dihentikan: aplikasi tetap di daftar dan tidak disembunyikan', () async {
    final (state, gw) = await make();
    await state.refreshActive();
    gw.failStop.add('com.wetv');
    final r = await state.closeApp('com.wetv');
    expect(r!.closed, 0);
    expect(state.activeApps.map((a) => a.app.package), ['com.wetv', 'com.chat']);
    await state.refreshActive();
    expect(state.activeApps.map((a) => a.app.package), contains('com.wetv'));
  });

  test('layanan Tutup Aplikasi belum aktif: tidak ada yang ditutup dan daftar utuh', () async {
    final (state, gw) = await make();
    gw.closeService = false;
    await state.refreshActive();
    expect(state.canCloseApps, isFalse);
    expect(await state.closeApp('com.wetv'), isNull);
    expect(await state.cleanRam(), isNull);
    expect(gw.stopped, isEmpty);
    expect(state.activeCount, 2);
  });

  test('layanan mati di tengah jalan (PlatformException): dilaporkan sebagai belum aktif, daftar utuh', () async {
    final (state, gw) = await make();
    await state.refreshActive();
    gw.closeService = true;
    gw.closeService = false; // dimatikan sesudah pengecekan terakhir
    expect(await state.closeApp('com.wetv'), isNull);
    expect(state.activeCount, 2);
  });

  test('kemajuan penutupan tampil sebagai "Menutup 2/3: Nama" dan dikosongkan setelah selesai', () async {
    final (state, gw) = await make();
    await state.refreshActive();
    gw.progressCb!(1, 3, 'Chrome');
    expect(state.closeProgress.value, 'Menutup 2/3: Chrome');
    await state.closeApp('com.wetv');
    expect(state.closeProgress.value, isNull);
  });
}
