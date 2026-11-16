import 'dart:async';

import 'package:flutter/services.dart' show PlatformException;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../alerts/planner.dart';
import '../alerts/scheduler.dart';
import '../core/format.dart';
import '../core/theme_pack.dart';
import '../platform/launcher_gateway.dart';
import 'models.dart';
import 'platforms.dart';

/// Jam yang bisa diganti di tes.
typedef Clock = DateTime Function();

/// Sesi menonton: dimulai saat membuka aplikasi drama dari launcher.
class _Session {
  _Session(this.package, this.startedAt, this.dramaId);
  final String package;
  final DateTime startedAt;
  final String? dramaId;
}

/// Satu-satunya sumber kebenaran: drama, pintasan, pengaturan, daftar aplikasi.
class AppState extends ChangeNotifier {
  AppState({
    required this.gateway,
    required this.scheduler,
    required this._prefs,
    Clock? now,
  }) : now = now ?? DateTime.now;

  static const _key = 'state_v1';

  final LauncherGateway gateway;
  final AlertScheduler scheduler;
  final SharedPreferences _prefs;
  final Clock now;

  List<Drama> _dramas = const [];
  List<WatchEntry> _history = const [];
  List<String> _pinned = const [];
  AppSettings _settings = const AppSettings();
  List<AppEntry> _apps = const [];
  Map<String, AppEntry> _byPackage = const {};
  AlertPermissions _perms = const AlertPermissions(notifications: true, exactAlarms: true);
  bool _defaultLauncher = true;
  bool _gestureNav = true;
  bool _appsLoaded = false;
  bool _usageAccess = true;
  bool _closeService = false;
  SilentStatus _silent = SilentStatus.notInstalled;
  List<ActiveApp> _active = const [];
  RamInfo _ram = const RamInfo(avail: 0, total: 0);
  final Map<String, int> _closedAt = {};

  /// Pengaturan dibuka oleh layanan Tutup Aplikasi sendiri; jangan dihitung sebagai aplikasi aktif.
  /// Shizuku juga disembunyikan: menutupnya akan mematikan mode senyap.
  static const _notShownAsActive = {'com.android.settings', 'moe.shizuku.privileged.api'};
  _Session? _session;
  String? pendingOpenDramaId;
  Timer? _syncTimer;

  /// "Menutup 2/5: Chrome" selama aplikasi ditutup satu per satu; null bila tidak sedang menutup.
  final ValueNotifier<String?> closeProgress = ValueNotifier(null);

  /// Sesi menonton yang baru selesai; layar menampilkan "Tadi nonton apa?" lalu mengosongkan.
  final ValueNotifier<Recap?> pendingRecap = ValueNotifier(null);

  /// Judul/tautan yang baru dibagikan dari aplikasi lain; layar editor membukanya lalu mengosongkan.
  final ValueNotifier<SharedDrama?> incomingShare = ValueNotifier(null);

  /// Hanya tema dan ukuran teks: MaterialApp tidak perlu dibangun ulang tiap episode bertambah.
  final ValueNotifier<(ThemeMode, TextSize, ThemePackId)> appearance =
      ValueNotifier((ThemeMode.dark, TextSize.normal, ThemePackId.dracin));

  List<Drama> get dramas => _dramas;
  List<WatchEntry> get history => _history;
  List<String> get pinned => _pinned;
  AppSettings get settings => _settings;
  List<AppEntry> get apps => _apps;
  bool get appsLoaded => _appsLoaded;
  AlertPermissions get permissions => _perms;
  bool get isDefaultLauncher => _defaultLauncher;
  bool get isGestureNavigation => _gestureNav;
  bool get hasUsageAccess => _usageAccess;
  /// Bisa menutup aplikasi: Shizuku siap (senyap) atau layanan Aksesibilitas aktif.
  /// Bila tidak, fitur ini hanya memantau.
  bool get canCloseApps => _closeService || _silent == SilentStatus.ready;
  SilentStatus get silentStatus => _silent;
  bool get accessibilityClose => _closeService;
  List<ActiveApp> get activeApps => _active;
  int get activeCount => _active.length;
  RamInfo get ram => _ram;
  AppEntry? appOf(String? package) => package == null ? null : _byPackage[package];

  /// Urut: yang terakhir ditonton dulu, lalu yang tayang paling dekat, lalu judul.
  List<Drama> get dramasByRecent {
    final t = now();
    final list = [..._dramas];
    list.sort((a, b) {
      if (a.lastWatchedMs != b.lastWatchedMs) return b.lastWatchedMs.compareTo(a.lastWatchedMs);
      final na = nextAiring(a, t), nb = nextAiring(b, t);
      if (na != null && nb != null) return na.compareTo(nb);
      if (na != null) return -1;
      if (nb != null) return 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return list;
  }

  /// Drama yang tampil di beranda menurut mode (Semua / Dracin / Drakor).
  List<Drama> get visibleDramas {
    final kind = _settings.viewMode.kind;
    final all = dramasByRecent;
    return kind == null ? all : all.where((d) => d.kind == kind).toList();
  }

  /// Ganti mode beranda; Dracin/Drakor juga memasang paket tema yang sesuai.
  void setMode(ViewMode mode) {
    final kind = mode.kind;
    updateSettings(_settings.copyWith(viewMode: mode, themePack: kind ?? _settings.themePack));
  }

  List<AppEntry> get pinnedApps => [
        for (final p in _pinned)
          if (_byPackage[p] != null) _byPackage[p]!,
      ];

  /// Aplikasi tontonan (dari daftar drama), unik, yang terakhir ditonton dulu.
  List<AppEntry> get watchApps {
    final seen = <String>{};
    return [
      for (final d in dramasByRecent)
        if (d.appPackage != null && _byPackage[d.appPackage] != null && seen.add(d.appPackage!)) _byPackage[d.appPackage]!,
    ];
  }

  bool isWatchApp(String package) => _dramas.any((d) => d.appPackage == package);

  /// Isi dock: aplikasi tontonan dulu, lalu pintasan pilihan sendiri (tanpa duplikat).
  List<AppEntry> get dockApps {
    final watch = watchApps;
    final seen = {for (final a in watch) a.package};
    return [...watch, for (final a in pinnedApps) if (seen.add(a.package)) a];
  }

  Future<void> pullDownNotifications() async {
    await gateway.expandNotifications();
  }

  // ---- Awal ----

  Future<void> load() async {
    final snap = Snapshot.decode(_prefs.getString(_key));
    _dramas = snap.dramas;
    _pinned = snap.pinned;
    _settings = snap.settings;
    _history = snap.history;
    appearance.value = (_settings.themeMode, _settings.textSize, _settings.themePack);
    gateway.onPackagesChanged(() => unawaited(refreshApps()));
    gateway.onShared(() => unawaited(pollShare()));
    gateway.onCloseProgress((done, total, label) => closeProgress.value = 'Menutup ${done + 1}/$total: $label');
    notifyListeners();
  }

  /// Dijalankan setelah frame pertama: daftar aplikasi, zona waktu, izin, pengingat.
  Future<void> warmUp({required void Function(Drama drama) onOpenFromNotification}) async {
    unawaited(refreshApps());
    unawaited(pollShare());
    try {
      final tzName = await gateway.timeZone();
      await scheduler.init(
        timeZone: tzName,
        onTap: (payload) => _handlePayload(payload, onOpenFromNotification),
      );
      _perms = await scheduler.permissions();
      _defaultLauncher = await gateway.isDefaultLauncher();
      _gestureNav = await gateway.isGestureNavigation();
      notifyListeners();
      unawaited(refreshActive());
      await scheduler.sync(planAlerts(_dramas, _settings));
      final launch = await scheduler.launchPayload();
      if (launch != null) _handlePayload(launch, onOpenFromNotification);
    } catch (e, st) {
      // Pengingat gagal tidak boleh mengganggu beranda; laporkan lalu lanjut.
      FlutterError.reportError(FlutterErrorDetails(exception: e, stack: st, library: 'dracin_launcher', context: ErrorDescription('menyiapkan pengingat')));
    }
  }

  void _handlePayload(String payload, void Function(Drama) cb) {
    if (!payload.startsWith('drama:')) return;
    final id = payload.substring(6);
    final d = _dramas.where((e) => e.id == id).firstOrNull;
    if (d != null) cb(d);
  }

  Future<void> refreshApps() async {
    try {
      _apps = await gateway.apps();
    } catch (_) {
      _apps = const [];
    }
    _byPackage = {for (final a in _apps) a.package: a};
    _appsLoaded = true;
    // Aplikasi yang sudah dihapus tidak boleh tersisa di pintasan.
    final cleaned = _pinned.where(_byPackage.containsKey).toList();
    if (cleaned.length != _pinned.length) {
      _pinned = cleaned;
      _persist();
    }
    notifyListeners();
  }

  Future<void> refreshPermissions() async {
    final before = _perms;
    _perms = await scheduler.permissions();
    _defaultLauncher = await gateway.isDefaultLauncher();
    _gestureNav = await gateway.isGestureNavigation();
    notifyListeners();
    // Izin alarm tepat waktu baru diberikan di Pengaturan: pasang ulang dengan mode tepat.
    if (_perms.exactAlarms != before.exactAlarms || _perms.notifications != before.notifications) {
      await scheduler.sync(planAlerts(_dramas, _settings));
    }
  }

  Future<void> requestPermissions() async {
    _perms = await scheduler.requestPermissions();
    await scheduler.sync(planAlerts(_dramas, _settings));
    notifyListeners();
  }

  // ---- Drama ----

  String newId() => 'd${now().microsecondsSinceEpoch.toRadixString(36)}';

  void saveDrama(Drama d) {
    final i = _dramas.indexWhere((e) => e.id == d.id);
    _dramas = [..._dramas];
    if (i < 0) {
      _dramas.add(d);
    } else {
      _dramas[i] = d;
    }
    _changed();
  }

  void removeDrama(String id) {
    _dramas = _dramas.where((e) => e.id != id).toList();
    _changed();
  }

  /// Tambah/kurangi episode; mengembalikan episode sebelumnya untuk "Urungkan".
  int bumpEpisode(String id, int delta) {
    final i = _dramas.indexWhere((e) => e.id == id);
    if (i < 0) return 0;
    final d = _dramas[i];
    final next = (d.episode + delta).clamp(0, 9999);
    _dramas = [..._dramas]..[i] = d.copyWith(
        episode: next,
        lastWatchedMs: delta > 0 ? now().millisecondsSinceEpoch : d.lastWatchedMs,
      );
    _changed();
    return d.episode;
  }

  void setEpisode(String id, int episode) {
    final i = _dramas.indexWhere((e) => e.id == id);
    if (i < 0) return;
    _dramas = [..._dramas]..[i] = _dramas[i].copyWith(episode: episode.clamp(0, 9999));
    _changed();
  }

  // ---- Pintasan ----

  bool isPinned(String package) => _pinned.contains(package);

  void togglePin(String package) {
    if (_pinned.contains(package)) {
      _pinned = _pinned.where((p) => p != package).toList();
    } else if (_pinned.length < 6) {
      _pinned = [..._pinned, package];
    } else {
      return;
    }
    _persist();
    notifyListeners();
  }

  bool get pinsFull => _pinned.length >= 6;

  // ---- Pengaturan ----

  void updateSettings(AppSettings s) {
    final alertsChanged = s.bedtimeEnabled != _settings.bedtimeEnabled || s.bedtimeMinute != _settings.bedtimeMinute;
    final breakOff = !s.breakEnabled && _settings.breakEnabled;
    _settings = s;
    appearance.value = (s.themeMode, s.textSize, s.themePack);
    if (breakOff) _endSession();
    if (alertsChanged) {
      _changed();
    } else {
      _persist();
      notifyListeners();
    }
  }

  void completeOnboarding() => updateSettings(_settings.copyWith(onboarded: true));

  // ---- Buka aplikasi ----

  /// Membuka aplikasi. Bila itu aplikasi tontonan, mulai sesi pengingat istirahat.
  Future<bool> launchPackage(String package) async {
    final ok = await gateway.launch(package);
    if (ok) await _startSession(package, null);
    return ok;
  }

  /// Aplikasi tontonan: dipakai oleh sebuah drama, atau platform yang dikenal (WeTV, iQIYI, ...).
  bool _isWatchPackage(String package) =>
      _dramas.any((d) => d.appPackage == package) || platforms.any((p) => p.packages.contains(package));

  Future<void> _startSession(String package, String? dramaId) async {
    if (!_isWatchPackage(package)) return;
    _session = _Session(package, now(), dramaId);
    if (_settings.breakEnabled) {
      await scheduler.scheduleBreak(
        minutes: _settings.breakMinutes,
        title: 'Istirahat sebentar',
        body: 'Sudah ${_durationText(_settings.breakMinutes)} menonton. Rehatkan mata, minum yang hangat, regangkan badan ya.',
      );
    }
  }

  /// Membuka drama: langsung ke halaman drama bila ada tautan dan aplikasi menanganinya,
  /// selain itu membuka aplikasinya saja.
  Future<bool> launchDrama(Drama d) async {
    final p = d.appPackage;
    if (p == null) return false;
    var ok = false;
    if (d.hasLink) ok = await gateway.openLink(p, d.link!);
    if (!ok) ok = await gateway.launch(p);
    if (ok) {
      // Membuka drama dari jenis lain: mode beranda ikut berganti (kecuali "Semua").
      final mode = _settings.viewMode;
      if (mode != ViewMode.all && mode.kind != d.kind) setMode(ViewModeX.of(d.kind));
      await _startSession(p, d.id);
    }
    return ok;
  }

  /// Ambil teks yang baru dibagikan dari aplikasi lain (WeTV, iQIYI, ...) dan urai.
  Future<void> pollShare() async {
    final text = await gateway.takeSharedText();
    if (text == null || text.trim().isEmpty) return;
    incomingShare.value = parseShare(text);
  }

  /// Launcher kembali ke depan: sesi menonton selesai, pengingat istirahat dibatalkan.
  void onResumed() {
    final session = _endSession();
    if (session != null) {
      final spent = now().difference(session.startedAt);
      // Terlalu singkat = hanya membuka lalu kembali; tidak dianggap menonton.
      if (spent >= const Duration(seconds: 60)) {
        unawaited(_finishSession(session, spent));
      }
    }
    unawaited(refreshPermissions());
    unawaited(refreshActive());
  }

  // ---- Aplikasi aktif, tutup aplikasi, bersihkan RAM ----

  /// Baca ulang aplikasi yang baru dipakai dan memori kosong. Aplikasi yang sudah ditutup
  /// dari sini tidak muncul lagi sampai dipakai kembali.
  Future<void> refreshActive() async {
    try {
      _usageAccess = await gateway.hasUsageAccess();
      _closeService = await gateway.forceStopEnabled();
      _silent = await gateway.silentStatus();
      _ram = await gateway.memoryInfo();
      if (!_usageAccess) {
        _active = const [];
      } else {
        final raw = await gateway.activeApps();
        final out = <ActiveApp>[];
        for (final u in raw) {
          if (_notShownAsActive.contains(u.package)) continue;
          final app = _byPackage[u.package];
          if (app == null) continue;
          final closed = _closedAt[u.package];
          if (closed != null && u.lastUsedMs <= closed) continue;
          out.add(ActiveApp(app: app, lastUsed: DateTime.fromMillisecondsSinceEpoch(u.lastUsedMs), foreground: u.foreground));
          if (out.length >= 24) break;
        }
        _active = out;
      }
    } catch (_) {
      _active = const [];
    }
    notifyListeners();
  }

  /// Menutup aplikasi lewat layanan "Tutup Aplikasi". Null bila layanan belum aktif.
  /// Aplikasi yang ditutup tidak muncul lagi sampai dipakai kembali.
  Future<RamResult?> closeApps(List<String> packages) async {
    if (!canCloseApps) {
      _closeService = await gateway.forceStopEnabled();
      _silent = await gateway.silentStatus();
      if (!canCloseApps) {
        notifyListeners();
        return null;
      }
    }
    final stamp = now().millisecondsSinceEpoch;
    final RamResult result;
    try {
      result = await gateway.forceStop(packages);
    } on PlatformException {
      _closeService = false;
      _silent = SilentStatus.notRunning;
      notifyListeners();
      return null;
    } finally {
      closeProgress.value = null;
    }
    // Hanya yang benar-benar berhenti yang disembunyikan; yang gagal tetap tampil.
    for (final p in result.stopped) {
      _closedAt[p] = stamp;
    }
    _ram = result.info;
    _active = _active.where((a) => !result.stopped.contains(a.app.package)).toList();
    notifyListeners();
    return result;
  }

  Future<RamResult?> closeApp(String package) => closeApps([package]);

  /// "Bersihkan RAM": menutup semua aplikasi aktif yang tidak sedang tampil.
  Future<RamResult?> cleanRam() => closeApps([for (final a in _active) if (!a.foreground) a.app.package]);

  Future<void> openAccessibilitySettings() => gateway.openAccessibilitySettings();

  Future<void> restartApp() => gateway.restartApp();

  /// Langkah berikutnya untuk mode senyap sesuai status Shizuku.
  Future<void> silentNextStep() async {
    switch (_silent) {
      case SilentStatus.notInstalled:
        await gateway.openShizukuStore();
      case SilentStatus.notRunning:
        await gateway.launch('moe.shizuku.privileged.api');
      case SilentStatus.needsPermission:
        await gateway.requestSilent();
      case SilentStatus.ready:
        break;
    }
  }


  /// Pesan singkat "Tercatat otomatis: ..." untuk ditampilkan layar; null bila tidak ada.
  final ValueNotifier<AutoLogged?> autoLogged = ValueNotifier(null);

  /// Sesi selesai: bila judulnya terbaca otomatis dari WeTV/iQIYI, langsung dicatat (dengan gambar kecil);
  /// bila tidak, tanyakan lewat "Tadi nonton apa?".
  Future<void> _finishSession(_Session s, Duration spent) async {
    NowWatchingInfo? seen;
    if (_settings.autoLog) {
      try {
        seen = await gateway.nowWatching(s.startedAt.millisecondsSinceEpoch);
        if (seen != null && seen.package != s.package) seen = null;
      } catch (_) {
        seen = null;
      }
    }
    var recap = Recap(package: s.package, dramaId: s.dramaId, startedAt: s.startedAt, duration: spent, title: seen?.title, thumb: seen?.thumb);
    if (seen == null) {
      pendingRecap.value = recap;
      return;
    }
    await gateway.clearNowWatching();
    final drama = _dramaFor(s.dramaId, seen.title, s.package);
    final entry = logWatch(recap, drama: drama, completed: false, auto: true);
    autoLogged.value = AutoLogged(entry: entry, recap: recap);
  }

  /// Drama yang cocok dengan judul terbaca: yang dibuka dari kartu, atau judul yang sama (tanpa huruf besar dan tanda baca).
  Drama? _dramaFor(String? openedId, String title, String package) {
    if (openedId != null) {
      final d = _dramas.where((e) => e.id == openedId).firstOrNull;
      if (d != null && titlesMatch(d.title, title)) return d;
    }
    final matches = _dramas.where((d) => titlesMatch(d.title, title)).toList();
    matches.sort((a, b) => (a.appPackage == package ? 0 : 1).compareTo(b.appPackage == package ? 0 : 1));
    return matches.firstOrNull;
  }

  _Session? _endSession() {
    final s = _session;
    if (s == null) return null;
    _session = null;
    unawaited(scheduler.cancelBreak());
    return s;
  }

  // ---- Riwayat tontonan ----

  /// Catat sesi [recap]. [drama] null bila pengguna tidak tahu/tidak memilih drama.
  /// [completed] menandai episode selesai dan menaikkan episode drama.
  WatchEntry logWatch(Recap recap, {Drama? drama, required bool completed, bool auto = false}) {
    final app = _byPackage[recap.package];
    final ep = drama?.nextEpisode;
    final entry = WatchEntry(
      id: 'w${recap.startedAt.microsecondsSinceEpoch.toRadixString(36)}',
      dramaId: drama?.id,
      title: drama?.title ?? recap.title ?? app?.label ?? recap.package,
      kind: drama?.kind ?? (_settings.viewMode.kind ?? ThemePackId.dracin),
      appPackage: recap.package,
      appLabel: app?.label,
      episode: ep,
      completed: completed && drama != null,
      thumb: recap.thumb,
      auto: auto,
      startMs: recap.startedAt.millisecondsSinceEpoch,
      durationSec: recap.duration.inSeconds.clamp(0, 24 * 3600),
    );
    _history = [entry, ..._history].take(300).toList();
    if (drama != null) {
      if (completed) {
        bumpEpisode(drama.id, 1);
      } else {
        saveDrama(drama.copyWith(lastWatchedMs: now().millisecondsSinceEpoch));
      }
    }
    pendingRecap.value = null;
    _persist();
    notifyListeners();
    return entry;
  }

  void skipRecap() => pendingRecap.value = null;

  void removeHistory(String id) {
    _history = _history.where((h) => h.id != id).toList();
    _persist();
    notifyListeners();
  }

  void clearHistory() {
    _history = const [];
    _persist();
    notifyListeners();
  }

  /// Total waktu menonton sejak [since], dipisah per jenis.
  Map<ThemePackId, Duration> watchTime(DateTime since) {
    final out = {for (final k in ThemePackId.values) k: Duration.zero};
    for (final h in _history) {
      if (h.start.isBefore(since)) continue;
      out[h.kind] = out[h.kind]! + h.duration;
    }
    return out;
  }

  bool get watching => _session != null;

  Future<void> sendTestNotification() => scheduler.showNow(
        title: 'Pengingat berfungsi',
        body: 'Begini tampilan pengingat tayang drama. Selamat menonton!',
      );

  // ---- Simpan & pasang ulang pengingat ----

  void _changed() {
    _persist();
    notifyListeners();
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(scheduler.sync(planAlerts(_dramas, _settings)));
    });
  }

  void _persist() {
    unawaited(_prefs.setString(_key, Snapshot(dramas: _dramas, pinned: _pinned, settings: _settings, history: _history).encode()));
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    appearance.dispose();
    incomingShare.dispose();
    pendingRecap.dispose();
    autoLogged.dispose();
    closeProgress.dispose();
    super.dispose();
  }
}

String _durationText(int minutes) {
  if (minutes < 60) return '$minutes menit';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h jam' : '$h jam ${two(m)} menit';
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

/// Hasil pencatatan otomatis, untuk pesan "Tercatat otomatis" dengan tombol Ubah.
class AutoLogged {
  const AutoLogged({required this.entry, required this.recap});
  final WatchEntry entry;
  final Recap recap;
}

String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u4e00-\u9fff\uac00-\ud7af]+'), '');

/// Judul sama setelah membuang huruf besar, spasi, dan tanda baca; atau salah satu memuat yang lain (>= 5 huruf).
bool titlesMatch(String a, String b) {
  final x = _norm(a), y = _norm(b);
  if (x.isEmpty || y.isEmpty) return false;
  if (x == y) return true;
  final short = x.length < y.length ? x : y;
  final long = x.length < y.length ? y : x;
  return short.length >= 5 && long.contains(short);
}
