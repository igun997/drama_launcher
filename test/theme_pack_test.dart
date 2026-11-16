import 'package:dracin_launcher/core/theme.dart';
import 'package:dracin_launcher/core/theme_pack.dart';
import 'package:dracin_launcher/data/models.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart' show Brightness;
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final l1 = a.computeLuminance(), l2 = b.computeLuminance();
  final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final pack in packs) {
    for (final (name, c) in [('gelap', pack.dark), ('terang', pack.light)]) {
      group('${pack.name} $name', () {
        test('teks utama >= 7:1 pada latar, kartu, dan kartu tinggi', () {
          expect(contrast(c.text, c.bg), greaterThanOrEqualTo(7));
          expect(contrast(c.text, c.surface), greaterThanOrEqualTo(7));
          expect(contrast(c.text, c.surfaceHigh), greaterThanOrEqualTo(7));
        });
        test('teks sekunder dan aksen >= 4.5:1 di semua permukaan', () {
          for (final bg in [c.bg, c.surface, c.surfaceHigh]) {
            expect(contrast(c.muted, bg), greaterThanOrEqualTo(4.5), reason: 'muted pada $bg');
            expect(contrast(c.accent, bg), greaterThanOrEqualTo(4.5), reason: 'accent pada $bg');
          }
        });
        test('teks tombol utama dan lencana aksen >= 4.5:1', () {
          expect(contrast(c.onPrimary, c.primary), greaterThanOrEqualTo(4.5));
          expect(contrast(c.bg, c.accent), greaterThanOrEqualTo(4.5)); // "Tayang hari ini"
        });
        test('garis batas (komponen UI) >= 3:1 pada latar', () {
          expect(contrast(c.outline, c.bg), greaterThanOrEqualTo(3));
        });
      });
    }
  }

  test('setiap paket punya id unik dan aset sendiri', () {
    expect(packs.map((p) => p.id).toSet(), ThemePackId.values.toSet());
    expect(packs.map((p) => p.hero).toSet(), hasLength(packs.length));
    for (final p in packs) {
      expect(p.dark.packId, p.id);
      expect(p.light.packId, p.id);
      expect(ThemePack.of(p.id), same(p));
    }
  });

  test('paket tema tersimpan dan nilai asing kembali ke Dracin', () {
    final s = AppSettings.fromJson(const AppSettings(themePack: ThemePackId.drakor).toJson());
    expect(s.themePack, ThemePackId.drakor);
    expect(AppSettings.fromJson({'themePack': 'tidak-ada'}).themePack, ThemePackId.dracin);
    expect(buildTheme(Brightness.dark, drakorPack).extension<DracinColors>()!.packId, ThemePackId.drakor);
  });
}
