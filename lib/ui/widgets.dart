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

/// Tarik ke bawah dari puncak daftar = kembali (menutup laci/halaman yang dibuka dengan geser ke atas).
/// Hanya hitungan lewat-ujung-atas: menggulir daftar seperti biasa tidak pernah memicunya.
class SwipeDownToClose extends StatefulWidget {
  const SwipeDownToClose({super.key, required this.child});
  final Widget child;

  @override
  State<SwipeDownToClose> createState() => _SwipeDownToCloseState();
}

class _SwipeDownToCloseState extends State<SwipeDownToClose> {
  double _pull = 0; // positif = ditarik ke bawah melewati puncak

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0) return false;
    if (n is ScrollStartNotification) {
      _pull = 0;
    } else if (n is OverscrollNotification && n.overscroll < 0 && n.dragDetails != null) {
      _pull -= n.overscroll;
    } else if (n is ScrollEndNotification) {
      final pull = _pull;
      _pull = 0;
      if (pull > 72) Navigator.of(context).maybePop();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(onNotification: _onScroll, child: widget.child);
}
