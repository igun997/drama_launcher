import 'package:material_ui/material_ui.dart';

import '../alerts/planner.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/theme_pack.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import 'motion.dart';
import 'widgets.dart';

/// Kartu satu drama: judul, progres episode, jadwal, dan tombol besar "Nonton".
class DramaCard extends StatelessWidget {
  const DramaCard({super.key, required this.drama, required this.onEdit, this.narrow = false});

  final Drama drama;
  final VoidCallback onEdit;

  /// Kartu sempit: tombol disusun atas-bawah. Ditentukan oleh daftar (bukan LayoutBuilder)
  /// karena baris kartu memakai IntrinsicHeight.
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = context.colors;
    final now = state.now();
    final today = drama.days.contains(now.weekday);
    final app = state.appOf(drama.appPackage);
    final theme = Theme.of(context);

    return Pressable(
      child: Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: today ? c.accent : c.outline.withValues(alpha: 0.4), width: today ? 2 : 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIcon(app: app, size: 60),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          drama.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
                        ),
                        const SizedBox(height: 6),
                        Pulse(
                          trigger: drama.episode,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: SwapText(
                                  drama.episode == 0 ? 'Belum mulai' : 'Sudah sampai Eps ${drama.episode}',
                                  style: theme.textTheme.titleSmall?.copyWith(color: c.accent, fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (drama.hasLink) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.link_rounded, size: 20, color: c.muted, semanticLabel: 'Membuka langsung ke halaman drama'),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        _ScheduleLine(drama: drama, today: today),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Ubah ${drama.title}',
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_outlined, semanticLabel: 'Ubah ${drama.title}'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Actions(drama: drama, onEdit: onEdit, narrow: narrow),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleLine extends StatelessWidget {
  const _ScheduleLine({required this.drama, required this.today});
  final Drama drama;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    if (!drama.hasSchedule) {
      return Text('Belum ada jadwal tayang', style: theme.textTheme.bodyMedium?.copyWith(color: c.muted));
    }
    final text = '${daysSummary(drama.days)} · ${clock(drama.minuteOfDay)}';
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              drama.remind ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
              size: 20,
              color: c.muted,
              semanticLabel: drama.remind ? 'Pengingat aktif' : 'Pengingat mati',
            ),
            const SizedBox(width: 6),
            Flexible(child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: c.muted))),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(border: Border.all(color: c.accent), borderRadius: BorderRadius.circular(10)),
          child: Text(drama.kind == ThemePackId.dracin ? 'Dracin' : 'Drakor', style: theme.textTheme.labelLarge?.copyWith(color: c.accent, fontWeight: FontWeight.w700)),
        ),
        if (today)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(10)),
            child: Text(
              'Tayang hari ini',
              style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSecondary, fontWeight: FontWeight.w800),
            ),
          ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.drama, required this.onEdit, required this.narrow});
  final Drama drama;
  final VoidCallback onEdit;
  final bool narrow;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    final watch = FilledButton.icon(
      onPressed: drama.hasApp ? () => openDrama(context, state, drama) : onEdit,
      icon: Icon(drama.hasApp ? Icons.play_arrow_rounded : Icons.apps_rounded, size: 28),
      label: Text(
        drama.hasApp ? 'Nonton Eps ${drama.nextEpisode}' : 'Pilih aplikasi',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
    );

    final done = OutlinedButton.icon(
      onPressed: () => _markDone(context, state),
      icon: const Icon(Icons.check_circle_outline_rounded),
      label: Text('Eps ${drama.nextEpisode} selesai', maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(60)),
    );

    if (narrow) {
      return Column(children: [watch, const SizedBox(height: 10), done]);
    }
    return Row(
      children: [
        Expanded(flex: 11, child: watch),
        const SizedBox(width: 12),
        Expanded(flex: 10, child: done),
      ],
    );
  }

  void _markDone(BuildContext context, AppState state) {
    final finished = drama.nextEpisode;
    final before = state.bumpEpisode(drama.id, 1);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Eps $finished selesai. Berikutnya Eps ${finished + 1}.'),
          duration: const Duration(seconds: 6),
          persist: false, // layanan Aksesibilitas kita membuat Flutter menahan snackbar ber-aksi selamanya
          action: SnackBarAction(label: 'Urungkan', onPressed: () => state.setEpisode(drama.id, before)),
        ),
      );
  }
}

/// Kartu "tambah drama" di ujung daftar.
class AddDramaCard extends StatelessWidget {
  const AddDramaCard({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: c.outline, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 96),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline_rounded, color: c.accent, size: 32),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Tambah drama',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: c.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Informasi singkat tayang berikutnya; lonceng bergoyang bila kurang dari 1 jam.
class NextUpBanner extends StatelessWidget {
  const NextUpBanner({super.key, required this.up, required this.onTap});
  final NextUp up;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = context.colors;
    final theme = Theme.of(context);
    final now = state.now();
    final diff = up.when.difference(now);
    final soon = diff.inMinutes < 60;
    final until = untilText(diff);
    final when = '${relativeDay(up.when, now)} ${clock(up.drama.minuteOfDay)}';
    final line = [when, episodeText(up.drama), if (until.isNotEmpty) until].join(' · ');
    final label = 'Tayang berikutnya: ${up.drama.title}. $line.${up.drama.hasApp ? ' Ketuk untuk membuka aplikasinya.' : ''}';

    return Pressable(
      child: Semantics(
        button: up.drama.hasApp,
        label: label,
        onTap: up.drama.hasApp ? onTap : null,
        excludeSemantics: true,
        child: Material(
          color: c.surfaceHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: c.accent.withValues(alpha: 0.6))),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: up.drama.hasApp ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  BellRing(active: soon, icon: Icons.notifications_active_rounded, color: c.accent, size: 38),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tayang berikutnya', style: theme.textTheme.labelLarge?.copyWith(color: c.muted)),
                        Text(
                          up.drama.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(line, style: theme.textTheme.bodyMedium?.copyWith(color: c.muted)),
                      ],
                    ),
                  ),
                  if (up.drama.hasApp) Icon(Icons.chevron_right_rounded, color: c.muted, size: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
