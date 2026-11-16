import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import 'motion.dart';
import 'widgets.dart';

/// Bantuan: semua gestur yang bisa dipakai, dengan kata-kata biasa.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _items = <_Gesture>[
    _Gesture(
      icon: Icons.swipe_up_alt_rounded,
      title: 'Semua aplikasi',
      how: 'Geser cepat ke atas dari dock (bar di bawah layar). Atau ketuk tombol "Semua".',
    ),
    _Gesture(
      icon: Icons.layers_rounded,
      title: 'Aplikasi aktif dan RAM',
      how: 'Geser pelan ke atas dari dock lalu lepas. Atau ketuk tombol "Aktif". Di sana bisa menutup aplikasi dan membersihkan RAM.',
    ),
    _Gesture(
      icon: Icons.swipe_down_alt_rounded,
      title: 'Kembali ke beranda',
      how: 'Di Semua aplikasi dan Aplikasi aktif: tarik daftar ke bawah saat sudah di paling atas. Tombol panah kembali juga bisa.',
    ),
    _Gesture(
      icon: Icons.notifications_none_rounded,
      title: 'Notifikasi',
      how: 'Tarik ke bawah dari bagian jam di atas beranda. Menggulir daftar drama tidak membuka notifikasi.',
    ),
    _Gesture(
      icon: Icons.swipe_left_rounded,
      title: 'Tutup satu aplikasi',
      how: 'Di Aplikasi aktif: geser kartu aplikasi ke kiri, atau ketuk Tutup.',
    ),
    _Gesture(
      icon: Icons.touch_app_rounded,
      title: 'Tekan lama ikon aplikasi',
      how: 'Di Semua aplikasi: tekan lama untuk memasang ke dock atau membuka Info aplikasi.',
    ),
    _Gesture(
      icon: Icons.undo_rounded,
      title: 'Salah tekan "Eps selesai"',
      how: 'Ketuk "Urungkan" di pesan yang muncul sebentar di bawah.',
    ),
    _Gesture(
      icon: Icons.restart_alt_rounded,
      title: 'Layar terasa macet',
      how: 'Pengaturan, lalu "Mulai ulang aplikasi".',
    ),
    _Gesture(
      icon: Icons.view_carousel_rounded,
      title: 'Tombol Recents tidak berfungsi',
      how: 'Bila launcher bawaan dimatikan, tombol Recents ikut mati. Pakai "Aktif" di dock sebagai penggantinya.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bantuan gestur'),
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded, semanticLabel: 'Kembali'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SwipeDownToClose(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 14),
                  child: Text('Semua gestur di launcher ini, satu per satu.', style: theme.textTheme.bodyLarge?.copyWith(color: c.muted)),
                ),
                for (var i = 0; i < _items.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Reveal(index: i, onceKey: 'help-$i', child: _GestureCard(item: _items[i])),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Gesture {
  const _Gesture({required this.icon, required this.title, required this.how});
  final IconData icon;
  final String title;
  final String how;
}

class _GestureCard extends StatelessWidget {
  const _GestureCard({required this.item});
  final _Gesture item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: c.surfaceHigh, borderRadius: BorderRadius.circular(18)),
                  child: Icon(item.icon, color: c.accent, size: 30),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(item.how, style: theme.textTheme.bodyLarge?.copyWith(color: c.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
