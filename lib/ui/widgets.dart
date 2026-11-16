import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../core/theme.dart';
import '../data/app_state.dart';

/// Ikon aplikasi dari Android; bila tidak ada, ikon bawaan.
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.app, this.size = 56});
  final AppEntry? app;
  final double size;

  @override
  Widget build(BuildContext context) {
    final a = app;
    if (a == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: context.colors.surfaceHigh, borderRadius: BorderRadius.circular(size * 0.28)),
        child: Icon(Icons.live_tv_rounded, size: size * 0.5, color: context.colors.accent),
      );
    }
    return Image(
      image: a.image,
      width: size,
      height: size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );
  }
}

/// Judul bagian layar; ditandai header untuk pembaca layar.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Buka drama (langsung ke tautannya bila ada); beri tahu bila gagal.
Future<void> openDrama(BuildContext context, AppState state, Drama drama) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await state.launchDrama(drama);
  if (!ok) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Aplikasi ini tidak bisa dibuka. Mungkin sudah dihapus.')));
  }
}

/// Buka aplikasi lewat launcher; beri tahu bila gagal.
Future<void> openPackage(BuildContext context, AppState state, String package) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await state.launchPackage(package);
  if (!ok) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Aplikasi ini tidak bisa dibuka. Mungkin sudah dihapus.')));
  }
}
