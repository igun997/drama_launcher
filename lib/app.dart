import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'core/theme_pack.dart';
import 'data/app_state.dart';
import 'data/models.dart';
import 'ui/drama_editor_page.dart';
import 'ui/home_page.dart';
import 'ui/recap_sheet.dart';

class DracinApp extends StatefulWidget {
  const DracinApp({super.key, required this.state});
  final AppState state;

  @override
  State<DracinApp> createState() => _DracinAppState();
}

class _DracinAppState extends State<DracinApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  late final Map<ThemePackId, (ThemeData, ThemeData)> _themes = {
    for (final p in packs) p.id: (buildTheme(Brightness.light, p), buildTheme(Brightness.dark, p)),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tombol Home saat launcher sudah di depan: kembali ke beranda.
    widget.state.gateway.onHome(() => _navigator.currentState?.popUntil((r) => r.isFirst));
    widget.state.incomingShare.addListener(_onShare);
    widget.state.pendingRecap.addListener(_onRecap);
  }

  /// Bagikan dari WeTV/iQIYI/dll.: buka editor drama baru yang sudah terisi.
  void _onShare() {
    final shared = widget.state.incomingShare.value;
    final context = _navigator.currentContext;
    if (shared == null || context == null) return;
    widget.state.incomingShare.value = null;
    _navigator.currentState?.popUntil((r) => r.isFirst);
    openDramaEditor(context, prefill: shared);
  }

  bool _recapOpen = false;

  /// Kembali dari WeTV/iQIYI/dll.: tanyakan apa yang tadi ditonton.
  void _onRecap() {
    final recap = widget.state.pendingRecap.value;
    final context = _navigator.currentContext;
    if (recap == null || context == null || _recapOpen) return;
    _recapOpen = true;
    showRecap(context, widget.state, recap).whenComplete(() => _recapOpen = false);
  }

  @override
  void dispose() {
    widget.state.pendingRecap.removeListener(_onRecap);
    widget.state.incomingShare.removeListener(_onShare);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) widget.state.onResumed();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<(ThemeMode, TextSize, ThemePackId)>(
      valueListenable: widget.state.appearance,
      builder: (context, look, _) {
        final (mode, size, pack) = look;
        final (light, dark) = _themes[pack]!;
        return MaterialApp(
          navigatorKey: _navigator,
          title: 'Dracin Launcher',
          debugShowCheckedModeBanner: false,
          theme: light,
          darkTheme: dark,
          themeMode: mode,
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final scaled = (mq.textScaler.scale(1) * size.scale).clamp(1.0, 2.2);
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarContrastEnforced: false,
              ),
              child: MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.linear(scaled)),
                child: AppScope(state: widget.state, child: child!),
              ),
            );
          },
          home: const HomePage(),
        );
      },
    );
  }
}
