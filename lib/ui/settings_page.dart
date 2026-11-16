import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../core/theme_pack.dart';
import 'motion.dart';
import 'widgets.dart';

/// Versi tampilan; samakan dengan `version:` di pubspec.yaml.
const kAppVersion = '1.0.0';

const _breakChoices = [60, 90, 120, 150];

String _breakLabel(int m) => switch (m) {
      60 => '1 jam',
      90 => '1,5 jam',
      120 => '2 jam',
      150 => '2,5 jam',
      _ => '$m menit',
    };

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.settings;
    final c = context.colors;
    final theme = Theme.of(context);
    final p = state.permissions;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back_rounded, semanticLabel: 'Kembali'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
            children: [
              // ---- Pengingat ----
              Reveal(
                onceKey: 'set-1',
                child: _Group(
                  title: 'Pengingat tayang',
                  children: [
                    _StatusTile(
                      ok: p.notifications,
                      okText: 'Notifikasi diizinkan',
                      badText: 'Notifikasi belum diizinkan',
                    ),
                    _StatusTile(
                      ok: p.exactAlarms,
                      okText: 'Alarm tepat waktu diizinkan',
                      badText: 'Alarm tepat waktu belum diizinkan (pengingat bisa telat)',
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        if (!p.all)
                          FilledButton.icon(
                            onPressed: state.requestPermissions,
                            icon: const Icon(Icons.notifications_active_outlined),
                            label: const Text('Izinkan pengingat'),
                          ),
                        OutlinedButton.icon(
                          onPressed: state.sendTestNotification,
                          icon: const Icon(Icons.campaign_outlined),
                          label: const Text('Coba pengingat sekarang'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // ---- Istirahat ----
              Reveal(
                index: 1,
                onceKey: 'set-2',
                child: _Group(
                  title: 'Istirahat mata',
                  children: [
                    SwitchListTile(
                      value: s.breakEnabled,
                      onChanged: (v) => state.updateSettings(s.copyWith(breakEnabled: v)),
                      minTileHeight: 72,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ingatkan istirahat'),
                      subtitle: const Text('Setelah aplikasi tontonan dibuka dari sini, diingatkan rehat bila belum kembali.'),
                    ),
                    if (s.breakEnabled) ...[
                      const SizedBox(height: 8),
                      Text('Ingatkan setelah', style: theme.textTheme.titleSmall?.copyWith(color: c.muted)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final m in _breakChoices)
                            ChoiceChip(
                              label: Text(_breakLabel(m)),
                              selected: s.breakMinutes == m,
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: s.breakMinutes == m ? c.onPrimary : c.text,
                              ),
                              onSelected: (_) => state.updateSettings(s.copyWith(breakMinutes: m)),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // ---- Tidur ----
              Reveal(
                index: 2,
                onceKey: 'set-3',
                child: _Group(
                  title: 'Waktu tidur',
                  children: [
                    SwitchListTile(
                      value: s.bedtimeEnabled,
                      onChanged: (v) => state.updateSettings(s.copyWith(bedtimeEnabled: v)),
                      minTileHeight: 72,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ingatkan berhenti nonton'),
                      subtitle: const Text('Setiap malam pada jam yang dipilih.'),
                    ),
                    if (s.bedtimeEnabled)
                      ListTile(
                        minTileHeight: 64,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.bedtime_outlined, color: c.accent, size: 32),
                        title: Text('Jam ${clock(s.bedtimeMinute)}'),
                        subtitle: const Text('Ketuk untuk mengubah'),
                        trailing: Icon(Icons.chevron_right_rounded, color: c.muted),
                        onTap: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay(hour: s.bedtimeMinute ~/ 60, minute: s.bedtimeMinute % 60),
                            helpText: 'Jam tidur',
                            cancelText: 'Batal',
                            confirmText: 'Pilih',
                            builder: (context, child) => MediaQuery(
                              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            ),
                          );
                          if (t != null) state.updateSettings(s.copyWith(bedtimeMinute: t.hour * 60 + t.minute));
                        },
                      ),
                  ],
                ),
              ),
              // ---- Tampilan ----
              Reveal(
                index: 3,
                onceKey: 'set-4',
                child: _Group(
                  title: 'Tampilan',
                  children: [
                    Text('Paket tema', style: theme.textTheme.titleSmall?.copyWith(color: c.muted)),
                    const SizedBox(height: 8),
                    _PackPicker(selected: s.themePack, onSelect: (p) => state.updateSettings(s.copyWith(themePack: p))),
                    const SizedBox(height: 16),
                    Text('Ukuran tulisan', style: theme.textTheme.titleSmall?.copyWith(color: c.muted)),
                    const SizedBox(height: 8),
                    SegmentedButton<TextSize>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
                      segments: [for (final t in TextSize.values) ButtonSegment(value: t, label: Text(t.label, textAlign: TextAlign.center))],
                      selected: {s.textSize},
                      onSelectionChanged: (v) => state.updateSettings(s.copyWith(textSize: v.first)),
                    ),
                    const SizedBox(height: 16),
                    Text('Warna', style: theme.textTheme.titleSmall?.copyWith(color: c.muted)),
                    const SizedBox(height: 8),
                    SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
                      segments: const [
                        ButtonSegment(value: ThemeMode.dark, label: Text('Gelap'), icon: Icon(Icons.dark_mode_outlined)),
                        ButtonSegment(value: ThemeMode.light, label: Text('Terang'), icon: Icon(Icons.light_mode_outlined)),
                        ButtonSegment(value: ThemeMode.system, label: Text('Ikut sistem'), icon: Icon(Icons.brightness_auto_outlined)),
                      ],
                      selected: {s.themeMode},
                      onSelectionChanged: (v) => state.updateSettings(s.copyWith(themeMode: v.first)),
                    ),
                  ],
                ),
              ),
              // ---- Launcher ----
              Reveal(
                index: 4,
                onceKey: 'set-5',
                child: _Group(
                  title: 'Layar utama dan gestur',
                  children: [
                    if (state.isDefaultLauncher)
                      const _StatusTile(ok: true, okText: 'Sudah jadi layar utama', badText: '')
                    else ...[
                      const Text('Agar tombol Home selalu kembali ke sini, jadikan Dracin Launcher layar utama.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => state.gateway.openHomeSettings(),
                        icon: const Icon(Icons.home_rounded),
                        label: const Text('Jadikan layar utama'),
                      ),
                    ],
                    const SizedBox(height: 8),
                    _StatusTile(
                      ok: true,
                      okText: state.isGestureNavigation ? 'Navigasi gestur aktif' : 'Navigasi 3 tombol aktif',
                      badText: '',
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => state.gateway.openGestureSettings(),
                      icon: const Icon(Icons.gesture_rounded),
                      label: const Text('Pengaturan navigasi sistem'),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      state.isGestureNavigation
                          ? 'Geser dari bawah layar: Home lewat launcher bawaan, jadi bisa ada kedipan singkat. '
                              'Untuk menghilangkannya: pakai navigasi 3 tombol, lalu matikan launcher bawaan.'
                          : 'Tombol Home langsung ke sini. Bila launcher bawaan dimatikan, tombol Recents tidak berfungsi: '
                              'pakai "Aktif" di dock.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                    ),
                  ],
                ),
              ),
              // ---- Catat otomatis ----
              Reveal(
                index: 5,
                onceKey: 'set-auto',
                child: _Group(
                  title: 'Catat tontonan otomatis',
                  children: [
                    SwitchListTile(
                      value: s.autoLog,
                      onChanged: (v) => state.updateSettings(s.copyWith(autoLog: v)),
                      minTileHeight: 72,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Catat dari WeTV dan iQIYI'),
                      subtitle: const Text(
                        'Judul yang terbaca di layar, plus satu tangkapan layar kecil, disimpan di riwayat. Hanya di perangkat ini.',
                      ),
                    ),
                    _StatusTile(
                      ok: state.accessibilityClose,
                      okText: 'Layanan Aksesibilitas aktif',
                      badText: 'Butuh layanan Aksesibilitas "Tutup Aplikasi & Catat Tontonan"',
                    ),
                    if (!state.accessibilityClose) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: state.openAccessibilitySettings,
                        icon: const Icon(Icons.accessibility_new_rounded),
                        label: const Text('Buka pengaturan aksesibilitas'),
                      ),
                    ],
                  ],
                ),
              ),
              // ---- Mulai ulang ----
              Reveal(
                index: 5,
                onceKey: 'set-restart',
                child: _Group(
                  title: 'Mulai ulang',
                  children: [
                    Text(
                      'Gunakan setelah mengaktifkan layanan Aksesibilitas, akses penggunaan, atau izin lain, '
                      'supaya aplikasi membaca ulang semuanya. Data dan pengaturan tidak hilang.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: state.restartApp,
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('Mulai ulang aplikasi'),
                    ),
                  ],
                ),
              ),
              // ---- Tentang ----
              Reveal(
                index: 5,
                onceKey: 'set-6',
                child: _Group(
                  title: 'Tentang',
                  children: [
                    Row(
                      children: [
                        ExcludeSemantics(child: Image.asset(context.pack.logo, width: 56, height: 56)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dracin Launcher $kAppVersion', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                              Text('PT Cipta Dua Saudara', style: theme.textTheme.bodyMedium),
                              SelectableText('www.ciptadusa.com', style: theme.textTheme.bodyMedium?.copyWith(color: c.accent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tanpa iklan, tanpa internet. Data hanya tersimpan di perangkat ini.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
                    ),
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

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [SectionTitle(title), ...children],
          ),
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.ok, required this.okText, required this.badText});
  final bool ok;
  final String okText;
  final String badText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = context.colors;
    final color = ok ? c.accent : theme.colorScheme.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Ikon + teks, bukan warna saja, yang membedakan status.
          Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(child: Text(ok ? okText : badText, style: theme.textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

/// Pilihan paket tema dengan pratinjau (gambar dan warna paket itu sendiri).
class _PackPicker extends StatelessWidget {
  const _PackPicker({required this.selected, required this.onSelect});
  final ThemePackId selected;
  final ValueChanged<ThemePackId> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cards = [
          for (final p in packs) _PackCard(pack: p, selected: p.id == selected, onTap: () => onSelect(p.id)),
        ];
        if (box.maxWidth < 520) {
          return Column(children: [for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: c)]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        );
      },
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({required this.pack, required this.selected, required this.onTap});
  final ThemePack pack;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = pack.dark; // pratinjau selalu memakai palet gelap paketnya
    final theme = Theme.of(context);
    return Pressable(
      child: Semantics(
        button: true,
        selected: selected,
        label: '${pack.name}. ${pack.tagline}.${selected ? ' Dipilih.' : ''}',
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: p.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: selected ? p.accent : p.outline.withValues(alpha: 0.5), width: selected ? 3 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 96,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(pack.hero, fit: BoxFit.cover, alignment: Alignment.topCenter, cacheWidth: 520, excludeFromSemantics: true),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.bg.withValues(alpha: 0), p.surface]),
                        ),
                      ),
                      if (selected)
                        Positioned(
                          right: 10,
                          top: 10,
                          child: CircleAvatar(radius: 16, backgroundColor: p.accent, child: Icon(Icons.check_rounded, color: p.bg, size: 22)),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(width: 14, height: 14, decoration: BoxDecoration(color: p.primary, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Container(width: 14, height: 14, decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle)),
                          const SizedBox(width: 10),
                          Text(pack.name, style: theme.textTheme.titleMedium?.copyWith(color: p.text, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(pack.tagline, style: theme.textTheme.bodyMedium?.copyWith(color: p.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
