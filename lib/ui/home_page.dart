import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';

import '../alerts/planner.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import 'active_apps_page.dart';
import 'apps_page.dart';
import 'drama_card.dart';
import 'drama_editor_page.dart';
import 'history_page.dart';
import 'motion.dart';
import 'settings_page.dart';
import 'widgets.dart';

double _sidePadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return math.max(20, (w - 1120) / 2);
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Beranda tidak boleh "ditutup" dengan tombol kembali.
      child: Scaffold(
        body: Stack(
          children: [
            const Positioned(top: 0, left: 0, right: 0, height: 320, child: _Backdrop()),
            const SafeArea(bottom: false, child: _Body()),
          ],
        ),
        bottomNavigationBar: const _Dock(),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pack = context.pack;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: Opacity(
              opacity: dark ? 0.9 : 0.2,
              child: HeroDrift(
                // Ganti paket tema: gambar berganti dengan memudar.
                child: AnimatedSwitcher(
                  duration: motionDuration(context, 650),
                  child: Image.asset(
                    pack.hero,
                    key: ValueKey(pack.id),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    alignment: Alignment.topCenter,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          ),
          if (pack.petals) PetalDrift(color: dark ? c.accent : c.primary),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.35, 1],
                colors: [c.bg.withValues(alpha: 0), c.bg],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final side = _sidePadding(context);
    final all = state.dramas;
    final dramas = state.visibleDramas;
    final up = nextUp(dramas.where((d) => d.remind).toList(), state.now());
    final needsPermission = dramas.any((d) => d.remind && d.hasSchedule) && !state.permissions.all;

    return _HomeGestures(
      child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(child: _Header(side: side)),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: side),
          sliver: SliverList.list(
            children: [
              if (needsPermission)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Reveal(onceKey: 'perm', child: _PermissionBanner(state: state)),
                ),
              if (up != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Reveal(
                    index: 1,
                    onceKey: 'next',
                    child: NextUpBanner(up: up, onTap: () => state.launchDrama(up.drama)),
                  ),
                ),
              if (all.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Reveal(index: 2, onceKey: 'mode', child: const _ModeBar()),
                ),
              SectionTitle(
                'Lanjut nonton',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () => openHistory(context),
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('Riwayat'),
                    ),
                    if (dramas.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => openDramaEditor(context, initialKind: state.settings.viewMode.kind),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Tambah'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (all.isEmpty)
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: side),
            sliver: const SliverToBoxAdapter(child: _EmptyState()),
          )
        else if (dramas.isEmpty)
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: side),
            sliver: SliverToBoxAdapter(child: _EmptyMode(mode: state.settings.viewMode)),
          )
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: side),
            sliver: _CardGrid(dramas: dramas),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    ),
    );
  }
}

/// Jam menit-an: berganti tepat di pergantian menit, tanpa timer per detik.
class MinuteTicker extends StatefulWidget {
  const MinuteTicker({super.key, required this.builder});
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<MinuteTicker> createState() => _MinuteTickerState();
}

class _MinuteTickerState extends State<MinuteTicker> {
  Timer? _timer;
  late DateTime _now;
  AppState? _state;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_state == null) {
      _state = AppScope.of(context);
      _now = _state!.now();
      _schedule();
    }
  }

  void _schedule() {
    final n = _state!.now();
    final wait = 60000 - n.second * 1000 - n.millisecond + 30;
    _timer = Timer(Duration(milliseconds: wait), () {
      if (!mounted) return;
      setState(() => _now = _state!.now());
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}

class _Header extends StatelessWidget {
  const _Header({required this.side});
  final double side;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(side, 18, side - 8 < 12 ? 12 : side - 8, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: MinuteTicker(
              builder: (context, now) {
                final minute = now.hour * 60 + now.minute;
                return Semantics(
                  container: true,
                  label: 'Pukul ${clock(minute)}, ${dateLong(now)}',
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(greeting(now.hour), style: theme.textTheme.titleMedium?.copyWith(color: c.accent, fontWeight: FontWeight.w800)),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          clock(minute),
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontSize: 76,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      Text(dateLong(now), style: theme.textTheme.titleMedium?.copyWith(color: c.text)),
                    ],
                  ),
                );
              },
            ),
          ),
          ExcludeSemantics(
            child: BreathingGlow(
              color: context.pack.glow,
              size: 64,
              child: Image.asset(context.pack.logo, width: 64, height: 64, gaplessPlayback: true),
            ),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            iconSize: 30,
            onPressed: () => Navigator.of(context).push(motionRoute((_) => const SettingsPage())),
            icon: const Icon(Icons.settings_outlined, semanticLabel: 'Pengaturan'),
          ),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    return Material(
      color: c.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: theme.colorScheme.error)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.notifications_off_outlined, color: theme.colorScheme.error, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Pengingat belum bisa berbunyi tepat waktu. Izinkan notifikasi dan alarm.',
                style: theme.textTheme.bodyLarge,
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(onPressed: state.requestPermissions, child: const Text('Izinkan')),
          ],
        ),
      ),
    );
  }
}

/// Kartu drama dalam 1 atau 2 kolom, tinggi mengikuti isi (aman untuk teks besar).
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.dramas});
  final List<Drama> dramas;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final cols = math.max(1, (constraints.crossAxisExtent / 540).floor());
        final cardWidth = (constraints.crossAxisExtent - 16 * (cols - 1)) / cols;
        final count = dramas.length + 1; // + kartu "Tambah"
        final rows = (count / cols).ceil();
        return SliverList.builder(
          itemCount: rows,
          itemBuilder: (context, row) {
            final children = <Widget>[];
            for (var col = 0; col < cols; col++) {
              final i = row * cols + col;
              Widget child = const SizedBox.shrink();
              if (i < dramas.length) {
                final d = dramas[i];
                child = Reveal(
                  index: i,
                  onceKey: 'card-${d.id}',
                  child: DramaCard(drama: d, narrow: cardWidth < 500, onEdit: () => openDramaEditor(context, drama: d)),
                );
              } else if (i == dramas.length) {
                child = Reveal(index: i, onceKey: 'add', child: AddDramaCard(onTap: () => openDramaEditor(context)));
              }
              if (col > 0) children.add(const SizedBox(width: 16));
              children.add(Expanded(child: child));
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    return Reveal(
      onceKey: 'empty',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            ExcludeSemantics(
              child: Sway(child: Image.asset(context.pack.empty, width: 260, gaplessPlayback: true)),
            ),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              child: Text('Belum ada drama', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambahkan drama yang sedang ditonton, pilih aplikasinya, lalu atur hari dan jam tayang. '
              'Nanti diingatkan sebelum tayang.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: c.muted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => openDramaEditor(context),
              icon: const Icon(Icons.add_rounded, size: 28),
              label: const Text('Tambah drama pertama'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 64), padding: const EdgeInsets.symmetric(horizontal: 28)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dock melayang di bawah: aplikasi tontonan + pintasan + "Semua".
/// Geser ke atas (atau tombol "Semua") membuka laci aplikasi.
class _Dock extends StatelessWidget {
  const _Dock();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = context.colors;
    final apps = state.dockApps;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Reveal(
          onceKey: 'dock',
          index: 3,
          child: Center(
            heightFactor: 1, // jangan melebar ke seluruh tinggi layar
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Semantics(
                container: true,
                label: 'Dock aplikasi. Geser ke atas: semua aplikasi. Geser ke atas lalu tahan: aplikasi aktif.',
                customSemanticsActions: {
                  const CustomSemanticsAction(label: 'Buka semua aplikasi'): () => openAppsPage(context),
                  const CustomSemanticsAction(label: 'Buka aplikasi aktif'): () => openActiveApps(context),
                },
                child: _DockSwipe(
                  child: Material(
                    color: c.surface.withValues(alpha: 0.96),
                    elevation: 12,
                    shadowColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(34),
                      side: BorderSide(color: c.outline.withValues(alpha: 0.35)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ExcludeSemantics(child: _Grabber()),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Aplikasi menggulir ke samping bila banyak; "Semua" selalu terlihat.
                              Flexible(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (final a in apps) _DockTile(app: a, watching: state.isWatchApp(a.package)),
                                    ],
                                  ),
                                ),
                              ),
                              if (apps.isNotEmpty) Container(width: 1, height: 56, margin: const EdgeInsets.symmetric(horizontal: 8), color: c.outline.withValues(alpha: 0.4)),
                              _ActiveTile(count: state.activeCount),
                              const _AllAppsTile(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pegangan kecil di atas dock; sesekali naik sedikit sebagai petunjuk "geser ke atas".
class _Grabber extends StatefulWidget {
  const _Grabber();

  @override
  State<_Grabber> createState() => _GrabberState();
}

class _GrabberState extends State<_Grabber> with SingleTickerProviderStateMixin, LoopingMotion {
  @override
  Duration get loopDuration => const Duration(milliseconds: 4200);
  @override
  double get restValue => 0;
  @override
  bool get reverseLoop => false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: loop,
        builder: (context, child) {
          final t = loop.value / 0.22;
          final dy = t < 1 ? -5 * math.sin(t * math.pi) : 0.0;
          return Transform.translate(offset: Offset(0, dy), child: child);
        },
        child: Container(
          width: 52,
          height: 6,
          decoration: BoxDecoration(color: c.muted.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(3)),
        ),
      ),
    );
  }
}

class _DockTile extends StatelessWidget {
  const _DockTile({required this.app, required this.watching});
  final AppEntry app;
  final bool watching;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = context.colors;
    return MergeSemantics(
      child: Semantics(
        button: true,
        hint: watching ? 'Aplikasi tontonan' : null,
        child: Pressable(
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => openPackage(context, state, app.package),
            onLongPress: watching ? null : () => state.togglePin(app.package),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: SizedBox(
                width: 80,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AppIcon(app: app, size: 60),
                        if (watching)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 2)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(app.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium),
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

class _AllAppsTile extends StatelessWidget {
  const _AllAppsTile();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MergeSemantics(
      child: Semantics(
        button: true,
        label: 'Semua aplikasi',
        excludeSemantics: true,
        onTap: () => openAppsPage(context),
        child: Pressable(
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => openAppsPage(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: SizedBox(
                width: 80,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(18)),
                      child: Icon(Icons.apps_rounded, color: c.text, size: 34),
                    ),
                    const SizedBox(height: 4),
                    Text('Semua', maxLines: 1, style: Theme.of(context).textTheme.labelMedium),
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

/// Gestur beranda tanpa tombol: tarik ke atas di mana saja membuka laci aplikasi,
/// tarik ke bawah dari atas membuka bilah notifikasi.
class _HomeGestures extends StatefulWidget {
  const _HomeGestures({required this.child});
  final Widget child;

  @override
  State<_HomeGestures> createState() => _HomeGesturesState();
}

class _HomeGesturesState extends State<_HomeGestures> {
  double _pull = 0; // + = lewat ujung bawah (geser ke atas), - = lewat ujung atas (geser ke bawah)

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollStartNotification) {
      _pull = 0;
    } else if (n is OverscrollNotification) {
      _pull += n.overscroll;
    } else if (n is ScrollEndNotification) {
      final pull = _pull;
      _pull = 0;
      if (pull > 48) {
        openAppsPage(context);
      } else if (pull < -48) {
        AppScope.of(context).pullDownNotifications();
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.child);
}

/// Geser ke atas pada dock, seperti gestur sistem:
/// sentak cepat = semua aplikasi; geser pelan lalu lepas (tahan) = aplikasi aktif.
class _DockSwipe extends StatefulWidget {
  const _DockSwipe({required this.child});
  final Widget child;

  @override
  State<_DockSwipe> createState() => _DockSwipeState();
}

class _DockSwipeState extends State<_DockSwipe> {
  double _dy = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => _dy = 0,
      onVerticalDragUpdate: (d) => _dy += d.delta.dy,
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0; // px/detik, negatif = ke atas
        final dy = _dy;
        _dy = 0;
        if (v < -700) {
          openAppsPage(context);
        } else if (dy <= -80 && v >= -700) {
          openActiveApps(context);
        } else if (v < -350) {
          openAppsPage(context);
        }
      },
      child: widget.child,
    );
  }
}

class _ActiveTile extends StatelessWidget {
  const _ActiveTile({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MergeSemantics(
      child: Semantics(
        button: true,
        label: count > 0 ? 'Aplikasi aktif, $count' : 'Aplikasi aktif',
        excludeSemantics: true,
        onTap: () => openActiveApps(context),
        child: Pressable(
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => openActiveApps(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: SizedBox(
                width: 80,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(18)),
                          child: Icon(Icons.layers_rounded, color: c.text, size: 32),
                        ),
                        if (count > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(11), border: Border.all(color: c.surface, width: 2)),
                              child: Text('$count', style: TextStyle(color: c.onPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Aktif', maxLines: 1, style: Theme.of(context).textTheme.labelMedium),
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

/// Mode beranda: Semua / Dracin / Drakor. Dracin dan Drakor juga memasang paket temanya.
class _ModeBar extends StatelessWidget {
  const _ModeBar();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    int count(ViewMode m) => m.kind == null ? state.dramas.length : state.dramas.where((d) => d.kind == m.kind).length;
    return SegmentedButton<ViewMode>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
      segments: [
        for (final m in ViewMode.values)
          ButtonSegment(
            value: m,
            label: Text('${m.label} (${count(m)})'),
            tooltip: m == ViewMode.all ? 'Tampilkan semua drama' : 'Mode ${m.label}: hanya drama ${m.label} dan tema ${m.label}',
          ),
      ],
      selected: {state.settings.viewMode},
      onSelectionChanged: (v) => state.setMode(v.first),
    );
  }
}

class _EmptyMode extends StatelessWidget {
  const _EmptyMode({required this.mode});
  final ViewMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          ExcludeSemantics(child: Sway(child: Image.asset(context.pack.empty, width: 220, gaplessPlayback: true))),
          const SizedBox(height: 8),
          Semantics(header: true, child: Text('Belum ada drama ${mode.label}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
          const SizedBox(height: 6),
          Text('Tambahkan, atau pilih "Semua" untuk melihat yang lain.', style: theme.textTheme.bodyLarge?.copyWith(color: c.muted), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => openDramaEditor(context, initialKind: mode.kind),
            icon: const Icon(Icons.add_rounded, size: 28),
            label: Text('Tambah drama ${mode.label}'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 60), padding: const EdgeInsets.symmetric(horizontal: 24)),
          ),
        ],
      ),
    );
  }
}
