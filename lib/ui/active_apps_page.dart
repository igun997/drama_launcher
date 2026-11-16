import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../platform/launcher_gateway.dart' show SilentStatus;
import 'motion.dart';
import 'widgets.dart';

Future<void> openActiveApps(BuildContext context) =>
    Navigator.of(context).push<void>(motionRoute((_) => const ActiveAppsPage(), up: true));

/// Aplikasi yang baru dipakai, dengan tombol tutup, geser-untuk-tutup, dan "Bersihkan RAM".
class ActiveAppsPage extends StatefulWidget {
  const ActiveAppsPage({super.key});

  @override
  State<ActiveAppsPage> createState() => _ActiveAppsPageState();
}

class _ActiveAppsPageState extends State<ActiveAppsPage> with WidgetsBindingObserver {
  bool _busy = false;
  AppState? _state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_state == null) {
      _state = AppScope.of(context);
      _state!.refreshActive();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Pulang dari layar "Akses penggunaan": cek ulang izinnya.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) _state?.refreshActive();
  }

  /// Menutup [packages] satu per satu; layar Info aplikasi tampil sebentar di sela-selanya.
  Future<void> _close(AppState state, List<String> packages) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final r = await state.closeApps(packages);
      if (!mounted) return;
      if (r == null) return; // layanan baru saja mati; kartu aktivasi muncul sendiri
      final text = r.closed == 0
          ? 'Tidak ada aplikasi yang bisa ditutup.'
          : r.freed > 0
              ? '${r.closed} aplikasi ditutup, ${bytesText(r.freed)} dilepas.'
              : '${r.closed} aplikasi ditutup. RAM sudah lega.';
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<String> _background(AppState state) => [for (final a in state.activeApps) if (!a.foreground) a.app.package];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = context.colors;
    final theme = Theme.of(context);
    final active = state.activeApps;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aplikasi aktif'),
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded, semanticLabel: 'Kembali'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Segarkan',
            icon: const Icon(Icons.refresh_rounded, semanticLabel: 'Segarkan'),
            onPressed: state.refreshActive,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SwipeDownToClose(
            child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              _RamCard(
                state: state,
                cleaning: _busy,
                canClean: state.hasUsageAccess && active.any((a) => !a.foreground),
                onClean: () => _close(state, _background(state)),
              ),
              const SizedBox(height: 16),
              // Tanpa layanan Tutup Aplikasi, halaman ini hanya memantau (daftar dan RAM).
              if (state.hasUsageAccess && !state.canCloseApps) ...[
                _ServiceCard(state: state),
                const SizedBox(height: 16),
              ] else if (state.hasUsageAccess && state.silentStatus != SilentStatus.ready) ...[
                _SilentHint(state: state),
                const SizedBox(height: 8),
              ],
              if (!state.hasUsageAccess)
                _AccessCard(state: state)
              else if (active.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      ExcludeSemantics(child: Image.asset(context.pack.empty, width: 180)),
                      const SizedBox(height: 8),
                      Semantics(header: true, child: Text('Tidak ada aplikasi aktif', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                      const SizedBox(height: 4),
                      Text('Aplikasi yang baru dipakai muncul di sini.', style: theme.textTheme.bodyLarge?.copyWith(color: c.muted)),
                    ],
                  ),
                )
              else ...[
                SectionTitle('Dipakai 6 jam terakhir (${active.length})'),
                if (state.canCloseApps)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text('Geser ke kiri untuk menutup, atau ketuk Tutup.', style: theme.textTheme.bodyMedium?.copyWith(color: c.muted)),
                  ),
                for (var i = 0; i < active.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Reveal(
                      index: i,
                      onceKey: 'active-${active[i].app.package}',
                      child: _ActiveTile(
                        item: active[i],
                        state: state,
                        busy: _busy,
                        canClose: state.canCloseApps,
                        onClose: () => _close(state, [active[i].app.package]),
                        onSwiped: () => _close(state, [active[i].app.package]),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _RamCard extends StatelessWidget {
  const _RamCard({required this.state, required this.cleaning, required this.canClean, required this.onClean});
  final AppState state;
  final bool cleaning;
  final bool canClean;
  final VoidCallback onClean;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    final ram = state.ram;
    final known = ram.total > 0;
    final percent = (ram.usedFraction * 100).round();
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory_rounded, color: c.accent, size: 32),
                const SizedBox(width: 12),
                Expanded(child: Text('Memori (RAM)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              ],
            ),
            const SizedBox(height: 12),
            if (known) ...[
              TweenAnimationBuilder<double>(
                tween: Tween(end: ram.usedFraction),
                duration: motionDuration(context, 700),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: v,
                    minHeight: 12,
                    backgroundColor: c.surfaceHigh,
                    color: v > 0.85 ? theme.colorScheme.error : c.accent,
                    semanticsLabel: 'RAM terpakai $percent persen',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kosong ${bytesText(ram.avail)} dari ${bytesText(ram.total)} ($percent% terpakai)',
                style: theme.textTheme.bodyLarge,
              ),
            ],
            const SizedBox(height: 14),
            if (state.canCloseApps) ...[
              FilledButton.icon(
                onPressed: cleaning || !canClean ? null : onClean,
                icon: cleaning
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 3))
                    : const Icon(Icons.cleaning_services_rounded, size: 26),
                label: ValueListenableBuilder<String?>(
                  valueListenable: state.closeProgress,
                  builder: (context, p, _) => Text(cleaning ? (p ?? 'Membersihkan...') : 'Bersihkan RAM'),
                ),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
              ),
              const SizedBox(height: 8),
              Text(
                'Menutup aplikasi satu per satu (Paksa berhenti); di mode Aksesibilitas layar Info aplikasi tampil sebentar. '
                'Android bisa membukanya lagi bila dibutuhkan, jadi hasilnya sementara. '
                'Aplikasi yang sedang tampil, keyboard, dan telepon tidak ditutup.',
                style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
              ),
            ] else
              Text(
                'Hanya memantau: RAM kosong dan aplikasi yang baru dipakai.',
                style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    return Material(
      color: c.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: c.accent.withValues(alpha: 0.6))),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text('Butuh izin "Akses penggunaan"', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
            const SizedBox(height: 8),
            Text(
              'Android tidak memberi tahu aplikasi lain apa yang sedang berjalan, kecuali Anda mengizinkan. '
              'Di layar berikutnya, pilih Dracin Launcher lalu nyalakan "Izinkan akses penggunaan". '
              'Data hanya dibaca di perangkat ini.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => state.gateway.openUsageAccessSettings(),
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Beri akses'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveTile extends StatelessWidget {
  const _ActiveTile({
    required this.item,
    required this.state,
    required this.busy,
    required this.canClose,
    required this.onClose,
    required this.onSwiped,
  });
  final ActiveApp item;
  final AppState state;
  final bool busy;

  /// Tanpa layanan Tutup Aplikasi tombol Tutup dan geser-untuk-menutup disembunyikan.
  final bool canClose;
  final VoidCallback onClose;
  final VoidCallback onSwiped;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    final app = item.app;
    final ago = item.foreground ? 'Sedang dipakai' : 'Dipakai ${agoText(state.now().difference(item.lastUsed))}';
    final card = Material(
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: c.outline.withValues(alpha: 0.4))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            AppIcon(app: app, size: 56),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  Text(ago, style: theme.textTheme.bodyMedium?.copyWith(color: item.foreground ? c.accent : c.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (canClose) ...[
              Semantics(
                button: true,
                label: 'Tutup ${app.label}',
                excludeSemantics: true,
                onTap: busy ? null : onClose,
                child: IconButton.outlined(
                  onPressed: busy ? null : onClose,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Tutup ${app.label}',
                ),
              ),
              const SizedBox(width: 6),
            ],
            Semantics(
              button: true,
              label: 'Buka ${app.label}',
              excludeSemantics: true,
              onTap: () => openPackage(context, state, app.package),
              child: IconButton.filled(
                onPressed: () => openPackage(context, state, app.package),
                icon: const Icon(Icons.open_in_new_rounded),
                tooltip: 'Buka ${app.label}',
              ),
            ),
          ],
        ),
      ),
    );
    if (!canClose) return card;
    return Dismissible(
      key: ValueKey('active-${app.package}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => Future.value(!busy),
      onDismissed: (_) => onSwiped(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: theme.colorScheme.error.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(22)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tutup', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onError, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Icon(Icons.close_rounded, color: theme.colorScheme.onError),
          ],
        ),
      ),
      child: card,
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    final (silentText, silentButton) = switch (state.silentStatus) {
      SilentStatus.notInstalled => ('Shizuku belum terpasang. Pasang, lalu mulai lewat Debugging nirkabel (sekali setiap tablet dihidupkan ulang).', 'Pasang Shizuku'),
      SilentStatus.notRunning => ('Shizuku sudah terpasang tetapi belum berjalan. Buka Shizuku lalu pilih Mulai.', 'Buka Shizuku'),
      SilentStatus.needsPermission => ('Izinkan Dracin Launcher memakai Shizuku.', 'Izinkan'),
      SilentStatus.ready => ('Siap.', 'Siap'),
    };
    return Material(
      color: c.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: c.outline.withValues(alpha: 0.5))),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text('Mau bisa menutup aplikasi juga?', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
            const SizedBox(height: 8),
            Text(
              'Sejak Android 14, aplikasi biasa tidak boleh menutup aplikasi lain secara langsung. Pilih salah satu cara '
              '(tanpa keduanya, halaman ini tetap berguna untuk memantau):',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 14),
            Text('1. Senyap, tanpa membuka layar apa pun (Shizuku)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: c.accent)),
            const SizedBox(height: 4),
            Text(silentText, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: state.silentNextStep,
              icon: const Icon(Icons.bolt_rounded),
              label: Text(silentButton),
            ),
            const SizedBox(height: 18),
            Text('2. Lewat layar Info aplikasi (Aksesibilitas)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: c.accent)),
            const SizedBox(height: 4),
            Text(
              'Nyalakan layanan "Tutup Aplikasi (Dracin Launcher)". Layanan ini hanya menekan "Paksa berhenti" dan "Oke" '
              'di layar Info aplikasi saat Anda menekan Tutup, dan tidak membaca aplikasi lain. Layar Pengaturan tampil sebentar '
              'untuk setiap aplikasi.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: state.openAccessibilitySettings,
                  icon: const Icon(Icons.accessibility_new_rounded),
                  label: const Text('Buka pengaturan aksesibilitas'),
                ),
                // Setelah layanan dinyalakan, mulai ulang supaya terbaca bersih.
                OutlinedButton.icon(
                  onPressed: state.restartApp,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Sudah dinyalakan? Mulai ulang aplikasi'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Saat hanya mode layar (Aksesibilitas) yang aktif: tawarkan mode senyap supaya Pengaturan tidak terbuka.
class _SilentHint extends StatelessWidget {
  const _SilentHint({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.bolt_rounded, color: c.accent),
        const SizedBox(width: 10),
        Expanded(child: Text('Tidak mau Pengaturan terbuka saat menutup? Pakai mode senyap (Shizuku).', style: theme.textTheme.bodyMedium?.copyWith(color: c.muted))),
        TextButton(onPressed: state.silentNextStep, child: const Text('Aktifkan')),
      ],
    );
  }
}
