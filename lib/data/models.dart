import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:material_ui/material_ui.dart' show ThemeMode;

import '../core/theme_pack.dart';

/// Aplikasi terpasang yang bisa dibuka (dari Android).
class AppEntry {
  AppEntry({required this.package, required this.label, required this.icon})
      : image = ResizeImage(MemoryImage(icon), width: 128, allowUpscaling: false);

  final String package;
  final String label;
  final Uint8List icon;

  /// Satu instance per aplikasi supaya ImageCache selalu kena.
  final ImageProvider image;
}

/// Satu drama yang sedang diikuti.
class Drama {
  const Drama({
    required this.id,
    required this.title,
    this.appPackage,
    this.appLabel,
    this.link,
    this.kind = ThemePackId.dracin,
    this.episode = 0,
    this.days = const {},
    this.minuteOfDay = 20 * 60,
    this.remind = true,
    this.leadMinutes = 10,
    this.lastWatchedMs = 0,
  });

  final String id;
  final String title;
  final String? appPackage;
  final String? appLabel;

  /// Tautan halaman drama (dari tombol Bagikan); dibuka langsung di aplikasi tontonan.
  final String? link;

  /// Jenis drama: Dracin (Tiongkok) atau Drakor (Korea).
  final ThemePackId kind;

  /// Episode terakhir yang selesai ditonton (0 = belum mulai).
  final int episode;

  /// Hari tayang, gaya DateTime.weekday (1 = Senin ... 7 = Minggu).
  final Set<int> days;
  final int minuteOfDay;
  final bool remind;
  final int leadMinutes;
  final int lastWatchedMs;

  int get nextEpisode => episode + 1;
  bool get hasSchedule => days.isNotEmpty;
  bool get hasApp => appPackage != null;
  bool get hasLink => link != null && link!.isNotEmpty;

  Drama copyWith({
    String? title,
    Object? appPackage = _keep,
    Object? appLabel = _keep,
    Object? link = _keep,
    ThemePackId? kind,
    int? episode,
    Set<int>? days,
    int? minuteOfDay,
    bool? remind,
    int? leadMinutes,
    int? lastWatchedMs,
  }) {
    return Drama(
      id: id,
      title: title ?? this.title,
      appPackage: identical(appPackage, _keep) ? this.appPackage : appPackage as String?,
      appLabel: identical(appLabel, _keep) ? this.appLabel : appLabel as String?,
      link: identical(link, _keep) ? this.link : link as String?,
      kind: kind ?? this.kind,
      episode: episode ?? this.episode,
      days: days ?? this.days,
      minuteOfDay: minuteOfDay ?? this.minuteOfDay,
      remind: remind ?? this.remind,
      leadMinutes: leadMinutes ?? this.leadMinutes,
      lastWatchedMs: lastWatchedMs ?? this.lastWatchedMs,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'appPackage': appPackage,
        'appLabel': appLabel,
        'link': link,
        'kind': kind.name,
        'episode': episode,
        'days': (days.toList()..sort()),
        'minuteOfDay': minuteOfDay,
        'remind': remind,
        'leadMinutes': leadMinutes,
        'lastWatchedMs': lastWatchedMs,
      };

  factory Drama.fromJson(Map<String, Object?> j) {
    int i(String k, int d) => (j[k] is num) ? (j[k] as num).toInt() : d;
    final rawDays = j['days'];
    return Drama(
      id: j['id'] as String,
      title: (j['title'] as String?) ?? '',
      appPackage: j['appPackage'] as String?,
      appLabel: j['appLabel'] as String?,
      link: j['link'] as String?,
      kind: ThemePackId.values.firstWhere((k) => k.name == j['kind'], orElse: () => ThemePackId.dracin),
      episode: i('episode', 0).clamp(0, 9999),
      days: rawDays is List ? rawDays.whereType<num>().map((e) => e.toInt()).where((d) => d >= 1 && d <= 7).toSet() : const {},
      minuteOfDay: i('minuteOfDay', 20 * 60).clamp(0, 1439),
      remind: (j['remind'] as bool?) ?? true,
      leadMinutes: i('leadMinutes', 10).clamp(0, 120),
      lastWatchedMs: i('lastWatchedMs', 0),
    );
  }
}

const Object _keep = Object();

/// Mode beranda: semua drama, atau hanya Dracin / Drakor (sekaligus mengganti paket tema).
enum ViewMode { all, dracin, drakor }

extension ViewModeX on ViewMode {
  String get label => switch (this) {
        ViewMode.all => 'Semua',
        ViewMode.dracin => 'Dracin',
        ViewMode.drakor => 'Drakor',
      };

  /// Jenis drama yang ditampilkan; null = semua.
  ThemePackId? get kind => switch (this) {
        ViewMode.all => null,
        ViewMode.dracin => ThemePackId.dracin,
        ViewMode.drakor => ThemePackId.drakor,
      };

  static ViewMode of(ThemePackId kind) => kind == ThemePackId.dracin ? ViewMode.dracin : ViewMode.drakor;
}

enum TextSize { normal, large, extraLarge }

extension TextSizeScale on TextSize {
  double get scale => switch (this) {
        TextSize.normal => 1.0,
        TextSize.large => 1.2,
        TextSize.extraLarge => 1.4,
      };
  String get label => switch (this) {
        TextSize.normal => 'Biasa',
        TextSize.large => 'Besar',
        TextSize.extraLarge => 'Sangat besar',
      };
}

class AppSettings {
  const AppSettings({
    this.breakEnabled = true,
    this.breakMinutes = 90,
    this.bedtimeEnabled = false,
    this.bedtimeMinute = 23 * 60,
    this.textSize = TextSize.normal,
    this.themeMode = ThemeMode.dark,
    this.themePack = ThemePackId.dracin,
    this.viewMode = ViewMode.all,
    this.onboarded = false,
  });

  final bool breakEnabled;
  final int breakMinutes;
  final bool bedtimeEnabled;
  final int bedtimeMinute;
  final TextSize textSize;
  final ThemeMode themeMode;
  final ThemePackId themePack;
  final ViewMode viewMode;
  final bool onboarded;

  AppSettings copyWith({
    bool? breakEnabled,
    int? breakMinutes,
    bool? bedtimeEnabled,
    int? bedtimeMinute,
    TextSize? textSize,
    ThemeMode? themeMode,
    ThemePackId? themePack,
    ViewMode? viewMode,
    bool? onboarded,
  }) {
    return AppSettings(
      breakEnabled: breakEnabled ?? this.breakEnabled,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      bedtimeEnabled: bedtimeEnabled ?? this.bedtimeEnabled,
      bedtimeMinute: bedtimeMinute ?? this.bedtimeMinute,
      textSize: textSize ?? this.textSize,
      themeMode: themeMode ?? this.themeMode,
      themePack: themePack ?? this.themePack,
      viewMode: viewMode ?? this.viewMode,
      onboarded: onboarded ?? this.onboarded,
    );
  }

  Map<String, Object?> toJson() => {
        'breakEnabled': breakEnabled,
        'breakMinutes': breakMinutes,
        'bedtimeEnabled': bedtimeEnabled,
        'bedtimeMinute': bedtimeMinute,
        'textSize': textSize.name,
        'themeMode': themeMode.name,
        'themePack': themePack.name,
        'viewMode': viewMode.name,
        'onboarded': onboarded,
      };

  factory AppSettings.fromJson(Map<String, Object?> j) {
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    return AppSettings(
      breakEnabled: (j['breakEnabled'] as bool?) ?? true,
      breakMinutes: ((j['breakMinutes'] as num?)?.toInt() ?? 90).clamp(15, 360),
      bedtimeEnabled: (j['bedtimeEnabled'] as bool?) ?? false,
      bedtimeMinute: ((j['bedtimeMinute'] as num?)?.toInt() ?? 23 * 60).clamp(0, 1439),
      textSize: pick(TextSize.values, j['textSize'], TextSize.normal),
      themeMode: pick(ThemeMode.values, j['themeMode'], ThemeMode.dark),
      themePack: pick(ThemePackId.values, j['themePack'], ThemePackId.dracin),
      viewMode: pick(ViewMode.values, j['viewMode'], ViewMode.all),
      onboarded: (j['onboarded'] as bool?) ?? false,
    );
  }
}

/// Seluruh data yang disimpan (SharedPreferences, satu kunci JSON).
class Snapshot {
  const Snapshot({this.dramas = const [], this.pinned = const [], this.settings = const AppSettings(), this.history = const []});

  final List<Drama> dramas;
  final List<WatchEntry> history;
  final List<String> pinned;
  final AppSettings settings;

  String encode() => jsonEncode({
        'v': 1,
        'dramas': dramas.map((d) => d.toJson()).toList(),
        'pinned': pinned,
        'settings': settings.toJson(),
        'history': history.map((h) => h.toJson()).toList(),
      });

  /// Data rusak atau kosong tidak boleh membuat aplikasi gagal terbuka.
  factory Snapshot.decode(String? raw) {
    if (raw == null || raw.isEmpty) return const Snapshot();
    try {
      final j = jsonDecode(raw) as Map<String, Object?>;
      return Snapshot(
        dramas: [
          for (final d in (j['dramas'] as List? ?? const []))
            if (d is Map<String, Object?>) Drama.fromJson(d),
        ],
        pinned: (j['pinned'] as List? ?? const []).whereType<String>().toList(),
        settings: AppSettings.fromJson((j['settings'] as Map?)?.cast<String, Object?>() ?? const {}),
        history: [
          for (final h in (j['history'] as List? ?? const []))
            if (h is Map<String, Object?>) WatchEntry.fromJson(h),
        ],
      );
    } catch (_) {
      return const Snapshot();
    }
  }
}

/// Aplikasi yang baru dipakai (dari Android), sebelum digabung dengan ikon/nama.
class ActiveUsage {
  const ActiveUsage({required this.package, required this.lastUsedMs, required this.foreground});
  final String package;
  final int lastUsedMs;
  final bool foreground;
}

class ActiveApp {
  const ActiveApp({required this.app, required this.lastUsed, required this.foreground});
  final AppEntry app;
  final DateTime lastUsed;
  final bool foreground;
}

class RamInfo {
  const RamInfo({required this.avail, required this.total});
  final int avail;
  final int total;
  int get used => total - avail;
  double get usedFraction => total <= 0 ? 0 : (used / total).clamp(0.0, 1.0);
}

class RamResult {
  const RamResult({required this.closed, required this.freed, required this.info, this.stopped = const []});
  final int closed;

  /// Paket yang benar-benar berhasil dihentikan.
  final List<String> stopped;

  /// Bisa nol atau negatif: Android mengelola memori sendiri.
  final int freed;
  final RamInfo info;
}

/// Satu sesi menonton yang tercatat dari launcher (dibuka dari sini, lalu kembali ke sini).
class WatchEntry {
  const WatchEntry({
    required this.id,
    required this.title,
    required this.kind,
    required this.startMs,
    required this.durationSec,
    this.dramaId,
    this.appPackage,
    this.appLabel,
    this.episode,
    this.completed = false,
  });

  final String id;
  final String? dramaId;

  /// Judul saat dicatat (tetap terbaca walau drama dihapus).
  final String title;
  final ThemePackId kind;
  final String? appPackage;
  final String? appLabel;

  /// Episode yang ditonton; null bila tidak diketahui.
  final int? episode;
  final bool completed;
  final int startMs;
  final int durationSec;

  DateTime get start => DateTime.fromMillisecondsSinceEpoch(startMs);
  Duration get duration => Duration(seconds: durationSec);

  Map<String, Object?> toJson() => {
        'id': id,
        'dramaId': dramaId,
        'title': title,
        'kind': kind.name,
        'appPackage': appPackage,
        'appLabel': appLabel,
        'episode': episode,
        'completed': completed,
        'startMs': startMs,
        'durationSec': durationSec,
      };

  factory WatchEntry.fromJson(Map<String, Object?> j) => WatchEntry(
        id: j['id'] as String,
        dramaId: j['dramaId'] as String?,
        title: (j['title'] as String?) ?? '',
        kind: ThemePackId.values.firstWhere((k) => k.name == j['kind'], orElse: () => ThemePackId.dracin),
        appPackage: j['appPackage'] as String?,
        appLabel: j['appLabel'] as String?,
        episode: (j['episode'] as num?)?.toInt(),
        completed: (j['completed'] as bool?) ?? false,
        startMs: (j['startMs'] as num?)?.toInt() ?? 0,
        durationSec: ((j['durationSec'] as num?)?.toInt() ?? 0).clamp(0, 24 * 3600),
      );
}

/// Sesi menonton yang baru selesai, menunggu pengguna memberi tahu apa yang ditonton.
class Recap {
  const Recap({required this.package, required this.startedAt, required this.duration, this.dramaId});
  final String package;
  final String? dramaId;
  final DateTime startedAt;
  final Duration duration;
}
