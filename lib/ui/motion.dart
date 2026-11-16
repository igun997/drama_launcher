import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Pengguna meminta tanpa animasi (Pengaturan Android > Aksesibilitas > Hapus animasi).
/// Semua gerak di aplikasi ini mengikuti pilihan itu: diam dan langsung tampil.
bool reduceMotion(BuildContext context) => MediaQuery.disableAnimationsOf(context);

Duration motionDuration(BuildContext context, int ms) => reduceMotion(context) ? Duration.zero : Duration(milliseconds: ms);

/// Transisi halaman: memudar sambil bergeser sedikit. [up] untuk laci aplikasi (naik dari bawah).
Route<T> motionRoute<T>(WidgetBuilder builder, {bool up = false, bool fullscreenDialog = false}) {
  return PageRouteBuilder<T>(
    fullscreenDialog: fullscreenDialog,
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, _, _) => builder(context),
    transitionsBuilder: (context, animation, _, child) {
      if (reduceMotion(context)) return child;
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: Offset(0, up ? 0.10 : 0.03), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Muncul bergantian saat layar dibuka: memudar dan naik sedikit.
/// Hanya diputar sekali per [onceKey] supaya tidak berulang saat daftar di-scroll.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child, this.index = 0, this.onceKey});

  final Widget child;
  final int index;
  final String? onceKey;

  static final Set<String> _played = {};

  @visibleForTesting
  static void resetForTest() => _played.clear();

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 460));
  late final Animation<double> _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  Timer? _delay;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final key = widget.onceKey;
    if (reduceMotion(context) || (key != null && Reveal._played.contains(key))) {
      _c.value = 1;
      return;
    }
    if (key != null) Reveal._played.add(key);
    _delay = Timer(Duration(milliseconds: 70 * widget.index.clamp(0, 8)), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.07), end: Offset.zero).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Menyusut sedikit saat ditekan. Tidak mengambil gestur dari anaknya.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child});
  final Widget child;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && !reduceMotion(context) ? 0.97 : 1,
        duration: motionDuration(context, 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Pengendali animasi berulang yang otomatis diam saat "hapus animasi" aktif.
mixin LoopingMotion<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController loop;

  Duration get loopDuration;
  double get restValue => 0.5;
  bool get loopEnabled => true;

  @override
  void initState() {
    super.initState();
    loop = AnimationController(vsync: this, duration: loopDuration, value: restValue);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final run = loopEnabled && !reduceMotion(context);
    if (run && !loop.isAnimating) {
      loop.repeat(reverse: reverseLoop);
    } else if (!run && loop.isAnimating) {
      loop
        ..stop()
        ..value = restValue;
    }
  }

  bool get reverseLoop => true;

  @override
  void dispose() {
    loop.dispose();
    super.dispose();
  }
}

/// Lentera yang "bernapas": cahaya di belakangnya menguat dan melemah pelan.
class BreathingGlow extends StatefulWidget {
  const BreathingGlow({super.key, required this.child, required this.color, this.size = 96});
  final Widget child;
  final Color color;
  final double size;

  @override
  State<BreathingGlow> createState() => _BreathingGlowState();
}

class _BreathingGlowState extends State<BreathingGlow> with SingleTickerProviderStateMixin, LoopingMotion {
  @override
  Duration get loopDuration => const Duration(milliseconds: 3200);

  late final Animation<double> _v = CurvedAnimation(parent: loop, curve: Curves.easeInOutSine);

  @override
  Widget build(BuildContext context) {
    final glow = widget.size * 1.9;
    return RepaintBoundary(
      child: SizedBox(
        width: glow,
        height: glow,
        child: AnimatedBuilder(
          animation: _v,
          builder: (context, child) {
            final v = _v.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: 0.22 + 0.4 * v,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [widget.color, widget.color.withValues(alpha: 0)]),
                    ),
                    child: SizedBox.square(dimension: glow),
                  ),
                ),
                Transform.scale(scale: 1 + 0.045 * v, child: child),
              ],
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Goyang pelan seperti lentera tergantung (untuk gambar keadaan kosong).
class Sway extends StatefulWidget {
  const Sway({super.key, required this.child});
  final Widget child;

  @override
  State<Sway> createState() => _SwayState();
}

class _SwayState extends State<Sway> with SingleTickerProviderStateMixin, LoopingMotion {
  @override
  Duration get loopDuration => const Duration(milliseconds: 5200);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: loop,
        builder: (context, child) {
          final t = Curves.easeInOutSine.transform(loop.value) * 2 - 1; // -1..1
          return Transform.translate(
            offset: Offset(0, -6 * t.abs()),
            child: Transform.rotate(angle: 0.03 * t, alignment: Alignment.topCenter, child: child),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Latar yang bergeser sangat pelan ke kiri-kanan (kesan kabut bergerak).
class HeroDrift extends StatefulWidget {
  const HeroDrift({super.key, required this.child});
  final Widget child;

  @override
  State<HeroDrift> createState() => _HeroDriftState();
}

class _HeroDriftState extends State<HeroDrift> with SingleTickerProviderStateMixin, LoopingMotion {
  @override
  Duration get loopDuration => const Duration(seconds: 48);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: loop,
        builder: (context, child) {
          final dx = (Curves.easeInOutSine.transform(loop.value) - 0.5) * 36;
          return Transform.translate(offset: Offset(dx, 0), child: Transform.scale(scale: 1.1, child: child));
        },
        child: widget.child,
      ),
    );
  }
}

/// Lonceng berguncang tiap beberapa detik saat tayang sudah dekat.
class BellRing extends StatefulWidget {
  const BellRing({super.key, required this.active, required this.icon, required this.color, this.size = 32});
  final bool active;
  final IconData icon;
  final Color color;
  final double size;

  @override
  State<BellRing> createState() => _BellRingState();
}

class _BellRingState extends State<BellRing> with SingleTickerProviderStateMixin, LoopingMotion {
  @override
  Duration get loopDuration => const Duration(milliseconds: 3600);
  @override
  double get restValue => 0;
  @override
  bool get loopEnabled => widget.active;
  @override
  bool get reverseLoop => false;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: loop,
        builder: (context, child) {
          final t = loop.value / 0.28;
          final angle = t < 1 ? math.sin(t * math.pi * 6) * 0.38 * (1 - t) : 0.0;
          return Transform.rotate(angle: angle, alignment: Alignment.topCenter, child: child);
        },
        child: Icon(widget.icon, color: widget.color, size: widget.size),
      ),
    );
  }
}

/// Membesar sebentar tiap kali [trigger] berubah (mis. nomor episode bertambah).
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.trigger, required this.child});
  final Object trigger;
  final Widget child;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(covariant Pulse old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && !reduceMotion(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final s = 1 + 0.18 * math.sin(Curves.easeOut.transform(_c.value) * math.pi);
        return Transform.scale(scale: s, child: child);
      },
      child: widget.child,
    );
  }
}

/// Angka/teks yang berganti dengan geser-vertikal halus.
class SwapText extends StatelessWidget {
  const SwapText(this.text, {super.key, this.style});
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: motionDuration(context, 240),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(animation),
          child: child,
        ),
      ),
      child: Text(text, key: ValueKey(text), style: style),
    );
  }
}

/// Kelopak sakura jatuh pelan (tema Drakor). Murni transform di satu CustomPaint;
/// tidak ada apa-apa yang digambar bila "hapus animasi" aktif.
class PetalDrift extends StatefulWidget {
  const PetalDrift({super.key, required this.color, this.count = 14});
  final Color color;
  final int count;

  @override
  State<PetalDrift> createState() => _PetalDriftState();
}

class _PetalDriftState extends State<PetalDrift> with SingleTickerProviderStateMixin, LoopingMotion {
  @override
  Duration get loopDuration => const Duration(seconds: 26);
  @override
  bool get reverseLoop => false;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return const SizedBox.shrink();
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PetalPainter(loop, widget.color, widget.count),
        size: Size.infinite,
      ),
    );
  }
}

class _PetalPainter extends CustomPainter {
  _PetalPainter(this.t, this.color, this.count) : super(repaint: t);
  final Animation<double> t;
  final Color color;
  final int count;

  // Nilai semu-acak yang tetap per kelopak (tanpa Random, supaya deterministik).
  static double _r(int i, int k) => ((i * 7919 + k * 104729) % 1000) / 1000;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < count; i++) {
      final speed = 0.6 + _r(i, 1) * 0.8; // putaran per siklus
      final phase = _r(i, 2);
      final progress = (t.value * speed + phase) % 1.0;
      final y = progress * (size.height + 40) - 20;
      final sway = math.sin((t.value * 2 * math.pi * (1 + _r(i, 3))) + phase * 6.28) * 22;
      final x = _r(i, 4) * size.width + sway;
      final scale = 0.7 + _r(i, 5) * 0.9;
      final fade = math.sin(progress * math.pi).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: 0.55 * fade);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(t.value * 6.28 * (0.5 + _r(i, 6)) + phase * 6.28)
        ..scale(scale);
      canvas.drawOval(const Rect.fromLTWH(-5, -3, 10, 6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PetalPainter old) => old.color != color || old.count != count;
}
