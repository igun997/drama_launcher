import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alerts/scheduler.dart';
import 'app.dart';
import 'data/app_state.dart';
import 'platform/launcher_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  final state = AppState(
    gateway: PlatformLauncherGateway(),
    scheduler: LocalAlertScheduler(),
    prefs: prefs,
  );
  await state.load();
  runApp(DracinApp(state: state));
  // Pekerjaan berat (daftar aplikasi, zona waktu, pengingat) setelah frame pertama,
  // supaya beranda muncul secepat mungkin.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(state.warmUp(onOpenFromNotification: (d) => unawaited(state.launchDrama(d))));
  });
}
