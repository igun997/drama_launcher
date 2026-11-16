
import 'package:flutter/services.dart';

import '../data/models.dart';

/// Pintu ke Android untuk fungsi launcher. Diganti palsu di tes.
abstract class LauncherGateway {
  Future<List<AppEntry>> apps();
  Future<bool> launch(String package);

  /// Membuka [url] di dalam aplikasi [package] (deep link). False bila aplikasi tidak menanganinya.
  Future<bool> openLink(String package, String url);

  /// Teks yang dikirim aplikasi lain lewat tombol Bagikan (sekali ambil), atau null.
  Future<String?> takeSharedText();
  Future<bool> openAppSettings(String package);
  Future<bool> openHomeSettings();
  Future<bool> isDefaultLauncher();

  /// Navigasi sistem memakai gestur (tanpa tombol).
  Future<bool> isGestureNavigation();
  Future<bool> openGestureSettings();

  /// Tarik-ke-bawah di beranda: buka bilah notifikasi.
  Future<bool> expandNotifications();
  Future<String> timeZone();

  /// Akses "Penggunaan aplikasi" (izin khusus) sudah diberikan pengguna.
  Future<bool> hasUsageAccess();
  Future<bool> openUsageAccessSettings();

  /// Aplikasi yang dipakai dalam 6 jam terakhir, terbaru dulu.
  Future<List<ActiveUsage>> activeApps();
  Future<RamInfo> memoryInfo();

  /// Layanan aksesibilitas "Tutup Aplikasi" aktif. Android 14+ melarang aplikasi biasa
  /// menutup aplikasi lain secara langsung, jadi penutupan lewat Info aplikasi > Paksa berhenti.
  /// Tanpa layanan ini fitur aplikasi aktif hanya memantau (daftar dan RAM).
  Future<bool> forceStopEnabled();
  Future<bool> openAccessibilitySettings();

  /// Mulai ulang aplikasi (proses baru), mis. setelah mengaktifkan layanan Aksesibilitas.
  Future<bool> restartApp();

  /// Menghentikan paksa tiap paket (satu per satu), kembali ke launcher, lalu mengukur memori.
  /// Melempar [PlatformException] bila layanan belum aktif.
  Future<RamResult> forceStop(List<String> packages);

  /// Dipanggil Android saat ada aplikasi dipasang/dihapus/diperbarui.
  void onPackagesChanged(void Function() callback);

  /// Kemajuan penutupan: aplikasi ke-[done] dari [total] sedang diproses.
  void onCloseProgress(void Function(int done, int total, String label) callback);

  /// Dipanggil saat ada teks baru dari tombol Bagikan.
  void onShared(void Function() callback);

  /// Dipanggil saat tombol Home ditekan ketika launcher sudah di depan.
  void onHome(void Function() callback);
}

class PlatformLauncherGateway implements LauncherGateway {
  PlatformLauncherGateway() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'packagesChanged':
          _packages?.call();
        case 'home':
          _home?.call();
        case 'shared':
          _shared?.call();
        case 'closeProgress':
          final m = call.arguments as Map<Object?, Object?>;
          _progress?.call((m['done'] as num).toInt(), (m['total'] as num).toInt(), m['label'] as String);
      }
      return null;
    });
  }

  static const _channel = MethodChannel('com.ciptadusa.dracin/launcher');
  void Function()? _packages;
  void Function()? _home;
  void Function()? _shared;
  void Function(int, int, String)? _progress;

  @override
  Future<List<AppEntry>> apps() async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>('getApps') ?? const [];
    return [
      for (final m in raw)
        AppEntry(
          package: m['package']! as String,
          label: m['label']! as String,
          icon: m['icon']! as Uint8List,
        ),
    ];
  }

  Future<bool> _bool(String method, [Map<String, Object?>? args]) async =>
      (await _channel.invokeMethod<bool>(method, args)) ?? false;

  @override
  Future<bool> launch(String package) => _bool('launch', {'package': package});

  @override
  Future<bool> openLink(String package, String url) => _bool('openLink', {'package': package, 'url': url});

  @override
  Future<String?> takeSharedText() => _channel.invokeMethod<String>('takeSharedText');

  @override
  Future<bool> openAppSettings(String package) => _bool('openAppSettings', {'package': package});

  @override
  Future<bool> openHomeSettings() => _bool('openHomeSettings');

  @override
  Future<bool> isDefaultLauncher() => _bool('isDefaultLauncher');

  @override
  Future<bool> isGestureNavigation() => _bool('isGestureNavigation');

  @override
  Future<bool> openGestureSettings() => _bool('openGestureSettings');

  @override
  Future<bool> expandNotifications() => _bool('expandNotifications');

  @override
  Future<bool> hasUsageAccess() => _bool('hasUsageAccess');

  @override
  Future<bool> openUsageAccessSettings() => _bool('openUsageAccessSettings');

  @override
  Future<List<ActiveUsage>> activeApps() async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>('activeApps') ?? const [];
    return [
      for (final m in raw)
        ActiveUsage(
          package: m['package']! as String,
          lastUsedMs: (m['lastUsedMs']! as num).toInt(),
          foreground: m['foreground'] == true,
        ),
    ];
  }

  RamInfo _ram(Map<Object?, Object?>? m) =>
      RamInfo(avail: (m?['avail'] as num?)?.toInt() ?? 0, total: (m?['total'] as num?)?.toInt() ?? 0);

  @override
  Future<RamInfo> memoryInfo() async => _ram(await _channel.invokeMapMethod<Object?, Object?>('memoryInfo'));

  @override
  Future<bool> forceStopEnabled() => _bool('forceStopEnabled');

  @override
  Future<bool> openAccessibilitySettings() => _bool('openAccessibilitySettings');

  @override
  Future<bool> restartApp() => _bool('restartApp');

  @override
  Future<RamResult> forceStop(List<String> packages) async {
    final m = await _channel.invokeMapMethod<Object?, Object?>('forceStop', {'packages': packages});
    return RamResult(
      closed: (m?['closed'] as num?)?.toInt() ?? 0,
      stopped: [for (final p in (m?['stopped'] as List? ?? const [])) p as String],
      freed: (m?['freed'] as num?)?.toInt() ?? 0,
      info: _ram(m),
    );
  }

  @override
  Future<String> timeZone() async => (await _channel.invokeMethod<String>('timeZone')) ?? 'Asia/Jakarta';

  @override
  void onPackagesChanged(void Function() callback) => _packages = callback;

  @override
  void onHome(void Function() callback) => _home = callback;

  @override
  void onShared(void Function() callback) => _shared = callback;

  @override
  void onCloseProgress(void Function(int done, int total, String label) callback) => _progress = callback;
}
