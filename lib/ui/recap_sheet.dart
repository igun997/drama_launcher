import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import 'widgets.dart';

/// Lembar "Tadi nonton apa?" setelah kembali dari aplikasi tontonan.
Future<void> showRecap(BuildContext context, AppState state, Recap recap) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => RecapSheet(recap: recap, state: state),
  ).whenComplete(() {
    // Ditutup dengan geser/ketuk di luar = dilewati.
    if (state.pendingRecap.value == recap) state.skipRecap();
  });
}

class RecapSheet extends StatefulWidget {
  const RecapSheet({super.key, required this.recap, required this.state});
  final Recap recap;
  final AppState state;

  @override
  State<RecapSheet> createState() => _RecapSheetState();
}

class _RecapSheetState extends State<RecapSheet> {
  Drama? _picked;

  @override
  void initState() {
    super.initState();
    final id = widget.recap.dramaId;
    if (id != null) _picked = widget.state.dramas.where((d) => d.id == id).firstOrNull;
  }

  void _done({required bool completed}) {
    widget.state.logWatch(widget.recap, drama: _picked, completed: completed);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    final state = widget.state;
    final app = state.appOf(widget.recap.package);
    final picked = _picked;
    // Drama dari aplikasi yang sama didahulukan.
    final candidates = [
      ...state.dramasByRecent.where((d) => d.appPackage == widget.recap.package),
      ...state.dramasByRecent.where((d) => d.appPackage != widget.recap.package),
    ].take(8).toList();

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(app: app, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          picked != null ? 'Selesai nonton ${picked.title}?' : 'Tadi nonton apa?',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
                        ),
                      ),
                      Text(
                        '${app?.label ?? widget.recap.package} · ${durationText(widget.recap.duration)}',
                        style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (picked == null) ...[
              if (candidates.isEmpty)
                Text('Belum ada drama. Tambahkan lewat tombol Tambah di beranda.', style: theme.textTheme.bodyLarge?.copyWith(color: c.muted))
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final d in candidates)
                      ActionChip(
                        label: Text(d.title, overflow: TextOverflow.ellipsis),
                        onPressed: () => setState(() => _picked = d),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _done(completed: false),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Catat tanpa judul'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: () => _done(completed: true),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 28),
                label: Text('Ya, Eps ${picked.nextEpisode} selesai'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _done(completed: false),
                icon: const Icon(Icons.pause_circle_outline_rounded),
                label: Text('Eps ${picked.nextEpisode} baru sebagian'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(60)),
              ),
              if (widget.recap.dramaId == null)
                TextButton(onPressed: () => setState(() => _picked = null), child: const Text('Bukan ini, pilih lain')),
            ],
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () {
                  state.skipRecap();
                  Navigator.of(context).pop();
                },
                child: const Text('Lewati'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
