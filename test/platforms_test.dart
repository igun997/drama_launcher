import 'package:dracin_launcher/data/app_state.dart';
import 'package:dracin_launcher/data/models.dart';
import 'package:dracin_launcher/data/platforms.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  group('mengenali platform dari tautan', () {
    test('WeTV dan iQIYI, termasuk subdomain; selain itu null', () {
      expect(platformForUrl('https://wetv.vip/id/play/abc?x=1')!.name, 'WeTV');
      expect(platformForUrl('https://www.iq.com/play/xyz')!.name, 'iQIYI');
      expect(platformForUrl('HTTPS://M.IQIYI.COM/v_1.html')!.name, 'iQIYI');
      expect(platformForUrl('https://evilwetv.vip/x'), isNull); // bukan subdomain wetv.vip
      expect(platformForUrl('https://contoh.com'), isNull);
      expect(platformForUrl('wetv.vip/tanpa-skema'), isNull);
    });

    test('tautan valid hanya http(s) dengan host', () {
      expect(isValidLink('https://wetv.vip/x'), isTrue);
      expect(isValidLink('javascript:alert(1)'), isFalse);
      expect(isValidLink('intent://x#Intent;end'), isFalse);
      expect(isValidLink('https://'), isFalse);
    });

    test('paket yang terpasang dipilih sesuai prioritas', () {
      final iq = platforms.firstWhere((p) => p.name == 'iQIYI');
      expect(installedPackage(iq, {'com.qiyi.video'}), 'com.qiyi.video');
      expect(installedPackage(iq, {'com.qiyi.video', 'com.iqiyi.i18n'}), 'com.iqiyi.i18n');
      expect(installedPackage(iq, {}), isNull);
      expect(installedPlatforms({'com.tencent.qqlivei18n'}).map((e) => e.$1.name), ['WeTV']);
    });
  });

  group('parseShare', () {
    test('judul dalam tanda kutip dan tautan', () {
      final s = parseShare('Tonton "Love Between Fairy and Devil" di WeTV https://wetv.vip/id/play/abc123).');
      expect(s.title, 'Love Between Fairy and Devil');
      expect(s.link, 'https://wetv.vip/id/play/abc123');
    });

    test('tanpa kutip: nama platform dan kata ajakan dibuang', () {
      final s = parseShare('Watch Moonlight Mist on iQIYI\nhttps://www.iq.com/play/moonlight-mist-19a');
      expect(s.title, 'Moonlight Mist');
      expect(s.link, 'https://www.iq.com/play/moonlight-mist-19a');
    });

    test('hanya tautan: judul kosong (diisi pengguna), tidak mengarang', () {
      final s = parseShare('https://wetv.vip/id/play/xyz');
      expect(s.title, isNull);
      expect(s.link, 'https://wetv.vip/id/play/xyz');
    });

    test('tanpa tautan: tetap menghasilkan judul', () {
      final s = parseShare('The Princess Weiyoung');
      expect(s.title, 'The Princess Weiyoung');
      expect(s.link, isNull);
    });
  });

  group('membuka drama', () {
    Future<(AppState, FakeGateway, FakeScheduler)> make() async {
      SharedPreferences.setMockInitialValues({});
      final gw = FakeGateway(apps: [AppEntry(package: 'com.tencent.qqlivei18n', label: 'WeTV', icon: kPng)]);
      final sch = FakeScheduler();
      final state = AppState(gateway: gw, scheduler: sch, prefs: await SharedPreferences.getInstance(), now: () => DateTime(2026, 11, 16, 19, 30));
      await state.load();
      await state.refreshApps();
      return (state, gw, sch);
    }

    const withLink = Drama(id: 'a', title: 'Love', appPackage: 'com.tencent.qqlivei18n', link: 'https://wetv.vip/id/play/abc');

    test('dengan tautan: dibuka langsung di aplikasinya dan sesi istirahat dimulai', () async {
      final (state, gw, sch) = await make();
      state.saveDrama(withLink);
      expect(await state.launchDrama(withLink), isTrue);
      expect(gw.openedLinks, [('com.tencent.qqlivei18n', 'https://wetv.vip/id/play/abc')]);
      expect(gw.launched, isEmpty);
      expect(sch.breaks, hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 450));
    });

    test('aplikasi tidak menangani tautan: jatuh ke membuka aplikasinya saja', () async {
      final (state, gw, _) = await make();
      state.saveDrama(withLink);
      gw.linkResult = false;
      expect(await state.launchDrama(withLink), isTrue);
      expect(gw.launched, ['com.tencent.qqlivei18n']);
      await Future<void>.delayed(const Duration(milliseconds: 450));
    });

    test('tanpa tautan: hanya membuka aplikasi', () async {
      final (state, gw, _) = await make();
      const plain = Drama(id: 'b', title: 'Lain', appPackage: 'com.tencent.qqlivei18n');
      await state.launchDrama(plain);
      expect(gw.openedLinks, isEmpty);
      expect(gw.launched, ['com.tencent.qqlivei18n']);
    });

    test('teks dari tombol Bagikan diurai dan diumumkan sekali', () async {
      final (state, gw, _) = await make();
      gw.shared = 'Tonton "Love Story" https://wetv.vip/id/play/q1';
      await state.pollShare();
      expect(state.incomingShare.value!.title, 'Love Story');
      expect(state.incomingShare.value!.link, 'https://wetv.vip/id/play/q1');
      state.incomingShare.value = null;
      await state.pollShare(); // sudah diambil: tidak muncul lagi
      expect(state.incomingShare.value, isNull);
    });

    test('tautan ikut tersimpan dan bisa dikosongkan', () {
      final d = Drama.fromJson(withLink.toJson());
      expect(d.link, 'https://wetv.vip/id/play/abc');
      expect(withLink.copyWith(link: null).hasLink, isFalse);
      expect(withLink.copyWith(title: 'X').link, withLink.link);
    });
  });
}
