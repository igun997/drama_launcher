import 'dart:ui' show Color;

import 'theme.dart';

/// Paket tema: satu set warna (gelap dan terang), ilustrasi, dan nuansa.
enum ThemePackId { dracin, drakor }

class ThemePack {
  const ThemePack({
    required this.id,
    required this.name,
    required this.tagline,
    required this.hero,
    required this.empty,
    required this.logo,
    required this.glow,
    required this.petals,
    required this.dark,
    required this.light,
  });

  final ThemePackId id;
  final String name;
  final String tagline;

  /// Aset (WebP) untuk kepala beranda, keadaan kosong, dan logo.
  final String hero;
  final String empty;
  final String logo;

  /// Warna cahaya di belakang logo.
  final Color glow;

  /// Kelopak sakura jatuh pelan di kepala beranda.
  final bool petals;

  final DracinColors dark;
  final DracinColors light;

  DracinColors colors(bool isDark) => isDark ? dark : light;

  static ThemePack of(ThemePackId id) => packs.firstWhere((p) => p.id == id);
}

/// Kontras sudah diuji di test/theme_pack_test.dart: teks utama >= 7:1,
/// teks sekunder, aksen, dan teks tombol >= 4.5:1 pada setiap permukaan.
const dracinPack = ThemePack(
  id: ThemePackId.dracin,
  name: 'Dracin',
  tagline: 'Drama Tiongkok · merah lentera dan emas',
  hero: 'assets/images/hero.webp',
  empty: 'assets/images/empty.webp',
  logo: 'assets/images/logo.webp',
  glow: Color(0xFFE0384F),
  petals: false,
  dark: DracinColors(
    packId: ThemePackId.dracin,
    bg: Color(0xFF17121F),
    surface: Color(0xFF241B33),
    surfaceHigh: Color(0xFF30244A),
    text: Color(0xFFF6EDE0),
    muted: Color(0xFFCBBFD8),
    primary: Color(0xFFB3122D),
    onPrimary: Color(0xFFFFF6EA),
    accent: Color(0xFFF2C14E),
    outline: Color(0xFF8E7FA3),
  ),
  light: DracinColors(
    packId: ThemePackId.dracin,
    bg: Color(0xFFFBF4EA),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF3E7D6),
    text: Color(0xFF1E1630),
    muted: Color(0xFF4F4360),
    primary: Color(0xFFA50F29),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF7A5200),
    outline: Color(0xFF7B6E8C),
  ),
);

const drakorPack = ThemePack(
  id: ThemePackId.drakor,
  name: 'Drakor',
  tagline: 'Drama Korea · pink sakura dan biru malam',
  hero: 'assets/images/hero_drakor.webp',
  empty: 'assets/images/empty_drakor.webp',
  logo: 'assets/images/logo_drakor.webp',
  glow: Color(0xFFF48FB1),
  petals: true,
  dark: DracinColors(
    packId: ThemePackId.drakor,
    bg: Color(0xFF111826),
    surface: Color(0xFF1B2333),
    surfaceHigh: Color(0xFF27314A),
    text: Color(0xFFF5F0EE),
    muted: Color(0xFFC4CCDA),
    primary: Color(0xFFB0285F),
    onPrimary: Color(0xFFFFF5F8),
    accent: Color(0xFFF7B6CA),
    outline: Color(0xFF8A96AE),
  ),
  light: DracinColors(
    packId: ThemePackId.drakor,
    bg: Color(0xFFFFF7F8),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFFBE7EE),
    text: Color(0xFF241A26),
    muted: Color(0xFF584A5C),
    primary: Color(0xFFB0245B),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF99204F),
    outline: Color(0xFF8A7890),
  ),
);

const packs = [dracinPack, drakorPack];
