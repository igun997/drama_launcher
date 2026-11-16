import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show PlatformException;
import 'package:dracin_launcher/alerts/planner.dart';
import 'package:dracin_launcher/alerts/scheduler.dart';
import 'package:dracin_launcher/data/models.dart';
import 'package:dracin_launcher/platform/launcher_gateway.dart';

/// PNG 1x1 valid, supaya Image.memory tidak gagal di tes.
final Uint8List kPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class FakeGateway implements LauncherGateway {
  FakeGateway({List<AppEntry>? apps}) : _apps = apps ?? [AppEntry(package: 'com.wetv', label: 'WeTV', icon: kPng)];

  final List<AppEntry> _apps;
  final launched = <String>[];
  bool launchResult = true;
  bool linkResult = true;
  final openedLinks = <(String, String)>[];
  String? shared;
  void Function()? sharedCb;
  void Function(int, int, String)? progressCb;
  bool gestureNav = true;
  bool usageAccess = true;
  List<ActiveUsage> usage = const [];
  bool closeService = true;
  SilentStatus silent = SilentStatus.notInstalled;
  int silentRequested = 0;
  int shizukuStoreOpened = 0;
  final failStop = <String>{};
  final stopped = <List<String>>[];
  int accessibilityOpened = 0;
  int restarts = 0;
  RamInfo ram = const RamInfo(avail: 2 * 1024 * 1024 * 1024, total: 6 * 1024 * 1024 * 1024);
  int usageSettingsOpened = 0;
  int expanded = 0;
  int gestureSettingsOpened = 0;
  void Function()? packagesCb;
  void Function()? homeCb;

  @override
  Future<List<AppEntry>> apps() async => _apps;
  @override
  Future<bool> launch(String package) async {
    launched.add(package);
    return launchResult;
  }

  @override
  Future<bool> openLink(String package, String url) async {
    openedLinks.add((package, url));
    return linkResult;
  }

  @override
  Future<String?> takeSharedText() async {
    final s = shared;
    shared = null;
    return s;
  }

  @override
  Future<bool> openAppSettings(String package) async => true;
  @override
  Future<bool> openHomeSettings() async => true;
  @override
  Future<bool> isDefaultLauncher() async => true;
  @override
  Future<bool> hasUsageAccess() async => usageAccess;
  @override
  Future<bool> openUsageAccessSettings() async {
    usageSettingsOpened++;
    return true;
  }

  @override
  Future<List<ActiveUsage>> activeApps() async => usage;
  @override
  Future<RamInfo> memoryInfo() async => ram;
  @override
  Future<bool> restartApp() async {
    restarts++;
    return true;
  }

  @override
  Future<SilentStatus> silentStatus() async => silent;
  @override
  Future<bool> requestSilent() async {
    silentRequested++;
    return true;
  }

  @override
  Future<bool> openShizukuStore() async {
    shizukuStoreOpened++;
    return true;
  }

  @override
  Future<bool> forceStopEnabled() async => closeService;
  @override
  Future<bool> openAccessibilitySettings() async {
    accessibilityOpened++;
    return true;
  }

  @override
  Future<RamResult> forceStop(List<String> packages) async {
    if (!closeService && silent != SilentStatus.ready) throw PlatformException(code: 'service_off');
    stopped.add(packages);
    ram = RamInfo(avail: ram.avail + 300 * 1024 * 1024, total: ram.total);
    final ok = [for (final p in packages) if (!failStop.contains(p)) p];
    return RamResult(closed: ok.length, stopped: ok, freed: 300 * 1024 * 1024, info: ram);
  }

  @override
  Future<bool> isGestureNavigation() async => gestureNav;
  @override
  Future<bool> openGestureSettings() async {
    gestureSettingsOpened++;
    return true;
  }

  @override
  Future<bool> expandNotifications() async {
    expanded++;
    return true;
  }

  @override
  Future<String> timeZone() async => 'Asia/Jakarta';
  @override
  void onPackagesChanged(void Function() callback) => packagesCb = callback;
  @override
  void onHome(void Function() callback) => homeCb = callback;
  @override
  void onShared(void Function() callback) => sharedCb = callback;
  @override
  void onCloseProgress(void Function(int done, int total, String label) callback) => progressCb = callback;
}

class FakeScheduler implements AlertScheduler {
  List<PlannedAlert> lastPlan = const [];
  int syncCount = 0;
  final breaks = <({int minutes, String title, String body})>[];
  int cancelBreaks = 0;
  int shown = 0;
  AlertPermissions perms = const AlertPermissions(notifications: true, exactAlarms: true);
  String? payload;
  bool initFails = false;

  @override
  Future<void> init({required String timeZone, required void Function(String payload) onTap}) async {
    if (initFails) throw StateError('init gagal');
  }
  @override
  Future<String?> launchPayload() async => payload;
  @override
  Future<void> sync(List<PlannedAlert> plan) async {
    lastPlan = plan;
    syncCount++;
  }

  @override
  Future<void> scheduleBreak({required int minutes, required String title, required String body}) async =>
      breaks.add((minutes: minutes, title: title, body: body));
  @override
  Future<void> cancelBreak() async => cancelBreaks++;
  @override
  Future<void> showNow({required String title, required String body}) async => shown++;
  @override
  Future<AlertPermissions> permissions() async => perms;
  @override
  Future<AlertPermissions> requestPermissions() async => perms;
  @override
  Future<void> openNotificationSettings() async {}
}
