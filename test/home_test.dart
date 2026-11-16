import 'package:dracin_launcher/app.dart';
import 'package:dracin_launcher/core/theme.dart';
import 'package:dracin_launcher/core/theme_pack.dart';
import 'package:dracin_launcher/data/app_state.dart';
import 'package:dracin_launcher/data/models.dart';
import 'package:dracin_launcher/ui/drama_card.dart';
import 'package:dracin_launcher/ui/motion.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

Future<(AppState, FakeGateway, FakeScheduler)> pumpApp(WidgetTester tester, {List<Drama> dramas = const [], DateTime Function()? clock}) async {
  tester.view.physicalSize = const Size(1200, 1920);
  tester.view.devicePixelRatio = 1.5;
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
  });
  Reveal.resetForTest();
  SharedPreferences.setMockInitialValues({});
  final gw = FakeGateway();
  final sch = FakeScheduler();
  final state = AppState(
    gateway: gw,
    scheduler: sch,
    prefs: await SharedPreferences.getInstance(),
    now: clock ?? () => DateTime(2026, 11, 16, 19, 30), // Senin malam
  );
  await state.load();
  for (final d in dramas) {
    state.saveDrama(d);
  }
  await state.refreshApps();
  await tester.pumpWidget(DracinApp(state: state));
  await tester.pump(const Duration(milliseconds: 500)); // melepas debounce pemasangan pengingat
  return (state, gw, sch);
}

const tonight = Drama(id: 'a', title: 'Love Story', appPackage: 'com.wetv', appLabel: 'WeTV', episode: 23, days: {1, 4}, minuteOfDay: 20 * 60);

void main() {
  testWidgets('beranda kosong: sapaan, jam, dan ajakan tambah drama', (tester) async {
    await pumpApp(tester);
    expect(find.text('Selamat malam'), findsOneWidget);
    expect(find.text('19.30'), findsOneWidget);
    expect(find.text('Senin, 16 November 2026'), findsOneWidget);
    expect(find.text('Belum ada drama'), findsOneWidget);
    expect(find.text('Tambah drama pertama'), findsOneWidget);
  });

  testWidgets('kartu drama: Nonton membuka aplikasi dan Selesai menaikkan episode dengan Urungkan', (tester) async {
    final (state, gw, _) = await pumpApp(tester, dramas: [tonight]);
    expect(find.text('Sudah sampai Eps 23'), findsOneWidget);
    expect(find.text('Tayang hari ini'), findsOneWidget);
    expect(find.text('Sen, Kam · 20.00'), findsOneWidget);
    // Banner tayang berikutnya: 30 menit lagi
    expect(find.bySemanticsLabel(RegExp('Tayang berikutnya: Love Story.*Hari ini 20.00.*Eps 24.*dalam 30 menit')), findsOneWidget);

    await tester.tap(find.text('Nonton Eps 24'));
    await tester.pump();
    expect(gw.launched, ['com.wetv']);

    await tester.tap(find.text('Eps 24 selesai'));
    await tester.pumpAndSettle();
    expect(state.dramas.single.episode, 24);
    expect(find.text('Eps 24 selesai. Berikutnya Eps 25.'), findsOneWidget);

    await tester.tap(find.text('Urungkan'));
    await tester.pumpAndSettle();
    expect(state.dramas.single.episode, 23);
    await tester.pump(const Duration(milliseconds: 500)); // debounce pemasangan pengingat selesai
  });

  testWidgets('semua kontrol utama punya nama untuk pembaca layar dan target sentuh >= 48dp', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, dramas: [tonight]);
    expect(find.bySemanticsLabel('Pengaturan'), findsOneWidget);
    expect(find.bySemanticsLabel('Ubah Love Story'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Pukul 19.30, Senin, 16 November 2026')), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('tanpa animasi: konten langsung tampil tanpa menunggu', (tester) async {
    await pumpApp(tester, dramas: [tonight]);
    // Tidak ada pump tambahan: Reveal harus sudah penuh bila "hapus animasi" aktif.
    final fade = tester.widget<FadeTransition>(find.descendant(of: find.byType(Reveal).first, matching: find.byType(FadeTransition)).first);
    expect(fade.opacity.value, 1);
  });

  testWidgets('tambah drama dari editor: judul wajib, aplikasi dipilih, tersimpan', (tester) async {
    final (state, _, _) = await pumpApp(tester);
    await tester.tap(find.text('Tambah drama pertama'));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Simpan');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Moonlight Mist');
    await tester.pump();
    await tester.tap(find.text('Pilih aplikasi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WeTV'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setiap hari'));
    await tester.pump();
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    final d = state.dramas.single;
    expect((d.title, d.appPackage, d.days.length), ('Moonlight Mist', 'com.wetv', 7));
    expect(find.descendant(of: find.byType(DramaCard), matching: find.text('Moonlight Mist')), findsOneWidget);
    expect(state.settings.onboarded, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('dock memuat aplikasi tontonan dan tombol Semua; geser ke atas membuka laci', (tester) async {
    await pumpApp(tester, dramas: [tonight]);
    final dock = find.bySemanticsLabel(RegExp('Dock aplikasi'));
    expect(dock, findsOneWidget);
    expect(find.descendant(of: find.byType(Material), matching: find.text('Semua')), findsOneWidget);
    expect(find.text('WeTV'), findsOneWidget);

    await tester.fling(find.byType(CustomScrollView), const Offset(0, -400), 2000);
    await tester.pumpAndSettle();
    expect(find.text('Cari aplikasi'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('geser pelan lalu tahan pada dock membuka aplikasi aktif; ubin Aktif menampilkan jumlah', (tester) async {
    final (state, gw, _) = await pumpApp(tester);
    gw.usage = [ActiveUsage(package: 'com.wetv', lastUsedMs: DateTime(2026, 11, 16, 19, 25).millisecondsSinceEpoch, foreground: false)];
    await state.refreshActive();
    await tester.pump();
    expect(find.text('Aktif'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // lencana jumlah

    await tester.timedDrag(find.text('Semua'), const Offset(0, -160), const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Bersihkan RAM'), findsOneWidget);
    expect(find.text('Dipakai 5 menit lalu'), findsOneWidget);
    expect(find.text('Cari aplikasi'), findsNothing);

    await tester.tap(find.byTooltip('Tutup WeTV'));
    await tester.pumpAndSettle();
    expect(gw.stopped, [['com.wetv']]);
    expect(find.text('Tidak ada aplikasi aktif'), findsOneWidget);
  });

  testWidgets('tanpa layanan Tutup Aplikasi: hanya memantau RAM dan daftar aplikasi aktif', (tester) async {
    final (state, gw, _) = await pumpApp(tester);
    gw.closeService = false;
    gw.usage = [ActiveUsage(package: 'com.wetv', lastUsedMs: DateTime(2026, 11, 16, 19, 25).millisecondsSinceEpoch, foreground: false)];
    await state.refreshActive();
    await tester.tap(find.text('Aktif'));
    await tester.pumpAndSettle();
    // Hanya memantau: ada RAM dan daftar, tetapi tidak ada tombol Tutup/Bersihkan RAM.
    expect(find.text('Mau bisa menutup aplikasi juga?'), findsOneWidget);
    expect(find.text('Pasang Shizuku'), findsOneWidget); // Shizuku belum terpasang di FakeGateway
    expect(find.text('Hanya memantau: RAM kosong dan aplikasi yang baru dipakai.'), findsOneWidget);
    expect(find.text('Bersihkan RAM'), findsNothing);
    expect(find.byTooltip('Tutup WeTV'), findsNothing);
    expect(find.byTooltip('Buka WeTV'), findsOneWidget);
    expect(find.text('Dipakai 5 menit lalu'), findsOneWidget);
    await tester.tap(find.text('Buka pengaturan aksesibilitas'));
    expect(gw.accessibilityOpened, 1);
    await tester.tap(find.text('Sudah dinyalakan? Mulai ulang aplikasi'));
    expect(gw.restarts, 1);
  });

  testWidgets('aplikasi aktif tanpa izin: kartu penjelasan dan tombol Beri akses', (tester) async {
    final (state, gw, _) = await pumpApp(tester);
    gw.usageAccess = false;
    await state.refreshActive();
    await tester.tap(find.text('Aktif'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Akses penggunaan'), findsOneWidget);
    await tester.tap(find.text('Beri akses'));
    expect(gw.usageSettingsOpened, 1);
  });

  testWidgets('tarik ke bawah di beranda membuka bilah notifikasi', (tester) async {
    final (_, gw, _) = await pumpApp(tester);
    expect(gw.expanded, 0);
    await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 2000);
    await tester.pumpAndSettle();
    expect(gw.expanded, 1);
    expect(find.text('Cari aplikasi'), findsNothing);
  });

  testWidgets('geser ke atas pada dock membuka laci', (tester) async {
    await pumpApp(tester);
    await tester.fling(find.text('Semua'), const Offset(0, -300), 2000);
    await tester.pumpAndSettle();
    expect(find.text('Cari aplikasi'), findsOneWidget);
  });

  testWidgets('ganti paket tema ke Drakor: hero, logo, dan warna berubah', (tester) async {
    final (state, _, _) = await pumpApp(tester);
    bool hasAsset(String name) => find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == name).evaluate().isNotEmpty;
    expect(hasAsset('assets/images/hero.webp'), isTrue);
    expect(hasAsset('assets/images/logo.webp'), isTrue);

    state.updateSettings(state.settings.copyWith(themePack: ThemePackId.drakor));
    await tester.pumpAndSettle();
    expect(hasAsset('assets/images/hero_drakor.webp'), isTrue);
    expect(hasAsset('assets/images/hero.webp'), isFalse);
    expect(hasAsset('assets/images/logo_drakor.webp'), isTrue);
    expect(hasAsset('assets/images/empty_drakor.webp'), isTrue);
    final ctx = tester.element(find.text('Belum ada drama'));
    expect(ctx.colors.packId, ThemePackId.drakor);
    expect(ctx.colors.bg, drakorPack.dark.bg);
  });

  testWidgets('pemilih paket tema di Pengaturan memilih Drakor dan menandai pilihan', (tester) async {
    final handle = tester.ensureSemantics();
    final (state, _, _) = await pumpApp(tester);
    await tester.tap(find.byTooltip('Pengaturan'));
    await tester.pumpAndSettle();
    final drakor = find.bySemanticsLabel(RegExp('^Drakor\\.'));
    await tester.ensureVisible(drakor);
    await tester.pumpAndSettle();
    await tester.tap(drakor);
    await tester.pumpAndSettle();
    expect(state.settings.themePack, ThemePackId.drakor);
    expect(find.bySemanticsLabel(RegExp('Drakor.*Dipilih')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('dibagikan dari WeTV: editor drama baru terisi judul, tautan, dan aplikasinya', (tester) async {
    final (state, gw, _) = await pumpApp(tester);
    gw.shared = 'Tonton "Love Story" https://wetv.vip/id/play/q1';
    // FakeGateway hanya punya com.wetv; platform WeTV asli tidak terpasang -> aplikasi tidak dipilih otomatis.
    await state.pollShare();
    await tester.pumpAndSettle();
    expect(find.text('Tambah drama'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Love Story'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'https://wetv.vip/id/play/q1'), findsOneWidget);
    expect(find.text('Pilih aplikasi'), findsOneWidget);
  });

  testWidgets('tautan WeTV memilihkan aplikasinya bila terpasang; tautan rusak menonaktifkan Simpan', (tester) async {
    tester.view.physicalSize = const Size(1200, 1920);
    tester.view.devicePixelRatio = 1.5;
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });
    Reveal.resetForTest();
    SharedPreferences.setMockInitialValues({});
    final gw = FakeGateway(apps: [AppEntry(package: 'com.tencent.qqlivei18n', label: 'WeTV', icon: kPng)]);
    final state = AppState(gateway: gw, scheduler: FakeScheduler(), prefs: await SharedPreferences.getInstance(), now: () => DateTime(2026, 11, 16, 19, 30));
    await state.load();
    await state.refreshApps();
    await tester.pumpWidget(DracinApp(state: state));
    await tester.pump();

    await tester.tap(find.text('Tambah drama pertama'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Love Story');
    await tester.enterText(find.widgetWithText(TextField, '').last, 'bukan tautan');
    await tester.pump();
    final save = find.widgetWithText(FilledButton, 'Simpan');
    await tester.ensureVisible(save);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(find.text('Tautan harus diawali https://'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'bukan tautan'), 'https://wetv.vip/id/play/q1');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    expect(find.descendant(of: find.byType(ListView), matching: find.text('WeTV')), findsWidgets); // aplikasi terpilih otomatis
    await tester.tap(save);
    await tester.pumpAndSettle();
    final d = state.dramas.single;
    expect((d.appPackage, d.link), ('com.tencent.qqlivei18n', 'https://wetv.vip/id/play/q1'));
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('mode Drakor menyaring kartu dan mengganti tema; riwayat tercatat lewat rekap', (tester) async {
    var t = DateTime(2026, 11, 16, 19, 30);
    const kr = Drama(id: 'kr', title: 'Moonlight', appPackage: 'com.wetv', appLabel: 'WeTV', kind: ThemePackId.drakor, episode: 10);
    final (state, gw, _) = await pumpApp(tester, dramas: [tonight, kr], clock: () => t);
    expect(find.text('Dracin (1)'), findsOneWidget);
    expect(find.text('Drakor (1)'), findsOneWidget);
    expect(find.descendant(of: find.byType(DramaCard), matching: find.text('Moonlight')), findsOneWidget);

    await tester.tap(find.text('Drakor (1)'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(DramaCard), matching: find.text('Love Story')), findsNothing);
    expect(find.descendant(of: find.byType(DramaCard), matching: find.text('Moonlight')), findsOneWidget);
    expect(tester.element(find.text('Lanjut nonton')).colors.packId, ThemePackId.drakor);

    // Tonton lalu kembali: lembar rekap menanyakan apa yang ditonton.
    await tester.tap(find.text('Nonton Eps 11'));
    await tester.pump();
    expect(gw.launched, ['com.wetv']);
    t = t.add(const Duration(minutes: 38));
    state.onResumed();
    await tester.pumpAndSettle();
    expect(find.text('Selesai nonton Moonlight?'), findsOneWidget);
    expect(find.textContaining('38 menit'), findsOneWidget);
    await tester.tap(find.text('Ya, Eps 11 selesai'));
    await tester.pumpAndSettle();
    expect(state.dramas.firstWhere((d) => d.id == 'kr').episode, 11);

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('Moonlight'), findsOneWidget);
    expect(find.text('Eps 11 selesai · Drakor'), findsOneWidget);
    expect(find.text('19.30 · 38 menit'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('rekap tanpa drama: pilih judul dulu, lalu catat', (tester) async {
    var t = DateTime(2026, 11, 16, 19, 30);
    final (state, _, _) = await pumpApp(tester, dramas: [tonight], clock: () => t);
    await state.launchPackage('com.wetv');
    t = t.add(const Duration(minutes: 12));
    state.onResumed();
    await tester.pumpAndSettle();
    expect(find.text('Tadi nonton apa?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, 'Love Story'));
    await tester.pumpAndSettle();
    expect(find.text('Selesai nonton Love Story?'), findsOneWidget);
    await tester.tap(find.text('Eps 24 baru sebagian'));
    await tester.pumpAndSettle();
    expect(state.history.single.completed, isFalse);
    expect(state.history.single.title, 'Love Story');
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('Pengaturan punya tombol Mulai ulang aplikasi', (tester) async {
    final (_, gw, _) = await pumpApp(tester);
    await tester.tap(find.byTooltip('Pengaturan'));
    await tester.pumpAndSettle();
    final restart = find.text('Mulai ulang aplikasi');
    await tester.scrollUntilVisible(restart, 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(restart);
    expect(gw.restarts, 1);
  });

  testWidgets('tombol Home dari Android menutup halaman dan kembali ke beranda', (tester) async {
    final (_, gw, _) = await pumpApp(tester);
    await tester.tap(find.byTooltip('Pengaturan'));
    await tester.pumpAndSettle();
    expect(find.text('Istirahat mata'), findsOneWidget);
    gw.homeCb!();
    await tester.pumpAndSettle();
    expect(find.text('Belum ada drama'), findsOneWidget);
  });

  testWidgets('pengaturan: ukuran tulisan besar membesarkan teks', (tester) async {
    final (state, _, _) = await pumpApp(tester);
    final before = tester.getSize(find.text('19.30')).height;
    state.updateSettings(state.settings.copyWith(textSize: TextSize.extraLarge));
    await tester.pump();
    // jam memakai FittedBox(scaleDown): cek lewat teks lain yang tidak diskalakan-turun
    final title = tester.getSize(find.text('Belum ada drama')).height;
    state.updateSettings(state.settings.copyWith(textSize: TextSize.normal));
    await tester.pump();
    expect(tester.getSize(find.text('Belum ada drama')).height, lessThan(title));
    expect(before, greaterThan(0));
  });
}
