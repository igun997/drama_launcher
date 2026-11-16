import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/theme_pack.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import 'motion.dart';
import 'widgets.dart';

Future<void> openHistory(BuildContext context) =>
    Navigator.of(context).push<void>(motionRoute((_) => const HistoryPage()));

String kindLabel(ThemePackId k) => k == ThemePackId.dracin ? 'Dracin' : 'Drakor';

/// Riwayat tontonan yang tercatat dari launcher, per hari, dengan ringkasan pekan ini.
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = context.colors;
    final theme = Theme.of(context);
    final now = state.now();
    final history = state.history;

    // Kelompokkan per hari (urutan sudah terbaru dulu).
    final groups = <String, List<WatchEntry>>{};
    for (final h in history) {
      groups.putIfAbsent(dayHeading(h.start, now), () => []).add(h);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat tontonan'),
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded, semanticLabel: 'Kembali'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          if (history.isNotEmpty)
            IconButton(
              tooltip: 'Hapus semua riwayat',
              icon: const Icon(Icons.delete_sweep_outlined, semanticLabel: 'Hapus semua riwayat'),
              onPressed: () => _confirmClear(context, state),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              _Summary(state: state, since: now.subtract(const Duration(days: 7))),
              const SizedBox(height: 16),
              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      ExcludeSemantics(child: Image.asset(context.pack.empty, width: 180)),
                      const SizedBox(height: 8),
                      Semantics(header: true, child: Text('Belum ada riwayat', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
                      const SizedBox(height: 4),
                      Text(
                        'Buka drama dari sini, lalu kembali: tontonan tercatat otomatis.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                )
              else
                for (final e in groups.entries) ...[
                  SectionTitle(e.key),
                  for (final h in e.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _EntryTile(entry: h, state: state),
                    ),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus semua riwayat?'),
        content: const Text('Catatan tontonan dihapus. Episode di kartu drama tidak berubah.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) state.clearHistory();
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.state, required this.since});
  final AppState state;
  final DateTime since;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    final t = state.watchTime(since);
    final total = t.values.fold(Duration.zero, (a, b) => a + b);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Semantics(
          container: true,
          label: 'Pekan ini menonton ${durationText(total)}. Dracin ${durationText(t[ThemePackId.dracin]!)}, Drakor ${durationText(t[ThemePackId.drakor]!)}.',
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('7 hari terakhir', style: theme.textTheme.labelLarge?.copyWith(color: c.muted)),
              const SizedBox(height: 4),
              Text(durationText(total), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: c.accent)),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final k in ThemePackId.values) ...[
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kindLabel(k), style: theme.textTheme.labelLarge?.copyWith(color: c.muted)),
                            Text(durationText(t[k]!), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                    if (k != ThemePackId.values.last) const SizedBox(width: 12),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.state});
  final WatchEntry entry;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    final app = state.appOf(entry.appPackage);
    final drama = state.dramas.where((d) => d.id == entry.dramaId).firstOrNull;
    final progress = entry.auto && entry.episode == null
        ? 'Otomatis'
        : entry.episode == null
        ? 'Tanpa episode'
        : entry.completed
            ? 'Eps ${entry.episode} selesai'
            : 'Eps ${entry.episode} sebagian';
    final time = '${clock(entry.start.hour * 60 + entry.start.minute)} · ${durationText(entry.duration)}';
    final canOpen = drama != null || (entry.appPackage != null && app != null);

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => state.removeHistory(entry.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(color: theme.colorScheme.error.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(22)),
        child: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.onError),
      ),
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: c.outline.withValues(alpha: 0.4))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _Leading(entry: entry, app: app),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.15)),
                    Text('$progress · ${kindLabel(entry.kind)}', style: theme.textTheme.bodyMedium?.copyWith(color: entry.completed ? c.accent : c.muted)),
                    Text(time, style: theme.textTheme.bodyMedium?.copyWith(color: c.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'Lanjut nonton ${entry.title}',
                excludeSemantics: true,
                onTap: canOpen ? () => _open(context, drama) : null,
                child: IconButton.filled(
                  tooltip: 'Lanjut nonton ${entry.title}',
                  onPressed: canOpen ? () => _open(context, drama) : null,
                  icon: const Icon(Icons.play_arrow_rounded, size: 30),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Drama? drama) {
    if (drama != null) {
      openDrama(context, state, drama);
    } else if (entry.appPackage != null) {
      openPackage(context, state, entry.appPackage!);
    }
  }
}

/// Gambar kecil tontonan (bila ada) dengan ikon aplikasi di sudutnya; selain itu hanya ikon aplikasi.
class _Leading extends StatelessWidget {
  const _Leading({required this.entry, required this.app});
  final WatchEntry entry;
  final AppEntry? app;

  @override
  Widget build(BuildContext context) {
    final path = entry.thumb;
    if (path == null || !File(path).existsSync()) return AppIcon(app: app, size: 52);
    final c = context.colors;
    return SizedBox(
      width: 96,
      height: 60,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(path), width: 96, height: 60, fit: BoxFit.cover, cacheWidth: 192, gaplessPlayback: true, errorBuilder: (_, _, _) => ColoredBox(color: c.surfaceHigh)),
            ),
          ),
          Positioned(right: -6, bottom: -6, child: AppIcon(app: app, size: 28)),
        ],
      ),
    );
  }
}
