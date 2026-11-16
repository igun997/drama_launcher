import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import 'motion.dart';
import 'widgets.dart';

/// Semua aplikasi (laci). Dengan [pick] sebagai pemilih: mengembalikan aplikasi yang diketuk.
Future<void> openAppsPage(BuildContext context) =>
    Navigator.of(context).push<void>(motionRoute((_) => const AppsPage(), up: true));

Future<AppEntry?> pickApp(BuildContext context) =>
    Navigator.of(context).push<AppEntry>(motionRoute((_) => const AppsPage(pick: true), up: true));

class AppsPage extends StatefulWidget {
  const AppsPage({super.key, this.pick = false});
  final bool pick;

  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = context.colors;
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final apps = q.isEmpty ? state.apps : state.apps.where((a) => a.label.toLowerCase().contains(q)).toList();
    final scale = MediaQuery.textScalerOf(context).scale(1);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pick ? 'Pilih aplikasi tontonan' : 'Semua aplikasi'),
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded, semanticLabel: 'Kembali'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Cari aplikasi',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        icon: const Icon(Icons.close_rounded, semanticLabel: 'Hapus pencarian'),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: !state.appsLoaded
                ? Center(
                    child: Semantics(
                      label: 'Memuat daftar aplikasi',
                      child: const CircularProgressIndicator(),
                    ),
                  )
                : apps.isEmpty
                    ? Center(
                        child: Text(
                          q.isEmpty ? 'Tidak ada aplikasi.' : 'Tidak ada aplikasi bernama "$_query".',
                          style: theme.textTheme.titleMedium?.copyWith(color: c.muted),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 128,
                          mainAxisExtent: 100 + 40 * scale,
                        ),
                        itemCount: apps.length,
                        itemBuilder: (context, i) => _AppTile(app: apps[i], pick: widget.pick),
                      ),
          ),
        ],
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.app, required this.pick});
  final AppEntry app;
  final bool pick;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            if (pick) {
              Navigator.of(context).pop(app);
            } else {
              openPackage(context, state, app.package);
            }
          },
          onLongPress: pick ? null : () => _showActions(context, state),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                AppIcon(app: app, size: 64),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    app.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) {
        final pinned = state.isPinned(app.package);
        final full = !pinned && state.pinsFull;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: AppIcon(app: app, size: 44),
                title: Text(app.label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              ),
              ListTile(
                minTileHeight: 64,
                enabled: !full,
                leading: Icon(pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded),
                title: Text(pinned ? 'Lepas dari pintasan' : 'Pasang di pintasan'),
                subtitle: full ? const Text('Pintasan penuh (maksimal 6). Lepas satu dulu.') : null,
                onTap: () {
                  state.togglePin(app.package);
                  Navigator.of(sheet).pop();
                },
              ),
              ListTile(
                minTileHeight: 64,
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Info aplikasi'),
                onTap: () {
                  state.gateway.openAppSettings(app.package);
                  Navigator.of(sheet).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
