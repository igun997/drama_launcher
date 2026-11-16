import 'package:flutter/services.dart' show Clipboard;
import 'package:material_ui/material_ui.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../core/theme_pack.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../data/platforms.dart';
import 'apps_page.dart';
import 'motion.dart';
import 'widgets.dart';

/// Tambah atau ubah drama. Setelah drama pertama disimpan, izin pengingat diminta sekali.
Future<void> openDramaEditor(BuildContext context, {Drama? drama, SharedDrama? prefill, ThemePackId? initialKind}) async {
  final state = AppScope.of(context);
  final saved = await Navigator.of(context).push<bool>(
    motionRoute((_) => DramaEditorPage(drama: drama, prefill: prefill, initialKind: initialKind), fullscreenDialog: true),
  );
  if (saved == true && !state.settings.onboarded) {
    state.completeOnboarding();
    await state.requestPermissions();
  }
}

class DramaEditorPage extends StatefulWidget {
  const DramaEditorPage({super.key, this.drama, this.prefill, this.initialKind});
  final Drama? drama;

  /// Jenis awal untuk drama baru (mis. dari mode Drakor di beranda).
  final ThemePackId? initialKind;

  /// Judul dan tautan dari tombol Bagikan (hanya untuk drama baru).
  final SharedDrama? prefill;

  @override
  State<DramaEditorPage> createState() => _DramaEditorPageState();
}

class _DramaEditorPageState extends State<DramaEditorPage> {
  late final TextEditingController _title = TextEditingController(text: widget.drama?.title ?? widget.prefill?.title ?? '');
  late final TextEditingController _link = TextEditingController(text: widget.drama?.link ?? widget.prefill?.link ?? '');
  late ThemePackId _kind = widget.drama?.kind ?? widget.initialKind ?? ThemePackId.dracin;
  bool _detected = false;
  late String? _package = widget.drama?.appPackage;
  late String? _appLabel = widget.drama?.appLabel;
  late int _episode = widget.drama?.episode ?? 0;
  late Set<int> _days = {...?widget.drama?.days};
  late int _minute = widget.drama?.minuteOfDay ?? 20 * 60;
  late bool _remind = widget.drama?.remind ?? true;
  late int _lead = widget.drama?.leadMinutes ?? 10;

  bool get _isNew => widget.drama == null;
  bool get _linkOk => _link.text.trim().isEmpty || isValidLink(_link.text);
  bool get _valid => _title.text.trim().isNotEmpty && _linkOk;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_detected) {
      _detected = true;
      _detectPlatform(AppScope.of(context));
    }
  }

  /// Tautan WeTV/iQIYI/dll. memilihkan aplikasinya bila terpasang dan belum dipilih.
  void _detectPlatform(AppState state) {
    if (_package != null) return;
    final p = platformForUrl(_link.text);
    if (p == null) return;
    final pkg = installedPackage(p, {for (final a in state.apps) a.package});
    if (pkg != null) {
      _package = pkg;
      _appLabel = state.appOf(pkg)?.label ?? p.name;
    }
  }

  Future<void> _pasteLink() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text;
    if (text == null || !mounted) return;
    final shared = parseShare(text);
    setState(() {
      _link.text = shared.link ?? text.trim();
      if (_title.text.trim().isEmpty && shared.title != null) _title.text = shared.title!;
      _detectPlatform(AppScope.of(context));
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pickApp() async {
    FocusScope.of(context).unfocus(); // jangan munculkan keyboard lagi sepulang dari pemilih
    final app = await pickApp(context);
    if (app != null) {
      setState(() {
        _package = app.package;
        _appLabel = app.label;
      });
    }
  }

  Future<void> _pickTime() async {
    FocusScope.of(context).unfocus();
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _minute ~/ 60, minute: _minute % 60),
      helpText: 'Jam tayang',
      cancelText: 'Batal',
      confirmText: 'Pilih',
      hourLabelText: 'Jam',
      minuteLabelText: 'Menit',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t != null) setState(() => _minute = t.hour * 60 + t.minute);
  }

  void _save() {
    final state = AppScope.of(context);
    final old = widget.drama;
    final d = (old ?? Drama(id: state.newId(), title: '')).copyWith(
      title: _title.text.trim(),
      appPackage: _package,
      appLabel: _appLabel,
      link: _link.text.trim().isEmpty ? null : _link.text.trim(),
      kind: _kind,
      episode: _episode,
      days: _days,
      minuteOfDay: _minute,
      remind: _remind,
      leadMinutes: _lead,
    );
    state.saveDrama(d);
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final state = AppScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus drama ini?'),
        content: Text('"${widget.drama!.title}" dan jadwal pengingatnya akan dihapus.'),
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
    if (ok == true && mounted) {
      state.removeDrama(widget.drama!.id);
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final c = context.colors;
    final theme = Theme.of(context);
    final app = state.appOf(_package);
    final hasDays = _days.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Tambah drama' : 'Ubah drama'),
        leading: IconButton(
          tooltip: 'Tutup tanpa menyimpan',
          icon: const Icon(Icons.close_rounded, semanticLabel: 'Tutup tanpa menyimpan'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              TextField(
                controller: _title,
                autofocus: _isNew && _title.text.isEmpty, // dari Bagikan sudah terisi: jangan buka keyboard
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Judul drama', hintText: 'mis. Love Between Fairy and Devil'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              SegmentedButton<ThemePackId>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
                segments: const [
                  ButtonSegment(value: ThemePackId.dracin, label: Text('Dracin (Tiongkok)')),
                  ButtonSegment(value: ThemePackId.drakor, label: Text('Drakor (Korea)')),
                ],
                selected: {_kind},
                onSelectionChanged: (v) => setState(() => _kind = v.first),
              ),
              const SizedBox(height: 20),
              const SectionTitle('Nonton di aplikasi'),
              _Tile(
                onTap: _pickApp,
                leading: AppIcon(app: app, size: 48),
                title: _appLabel ?? 'Pilih aplikasi',
                subtitle: _package == null ? 'Tombol "Nonton" akan membuka aplikasi ini' : 'Ketuk untuk mengganti',
                trailing: Icons.chevron_right_rounded,
              ),
              const SizedBox(height: 12),
              _PlatformChips(
                selected: _package,
                onSelect: (pkg, label) => setState(() {
                  _package = pkg;
                  _appLabel = label;
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _link,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _detectPlatform(state)),
                decoration: InputDecoration(
                  labelText: 'Tautan drama (opsional)',
                  hintText: 'https://wetv.vip/...',
                  helperText: 'Dari tombol Bagikan di WeTV, iQIYI, dll. Tombol "Nonton" langsung membuka halaman drama.',
                  helperMaxLines: 3,
                  errorText: _linkOk ? null : 'Tautan harus diawali https://',
                  suffixIcon: IconButton(
                    tooltip: 'Tempel tautan',
                    icon: const Icon(Icons.content_paste_rounded, semanticLabel: 'Tempel tautan'),
                    onPressed: _pasteLink,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const SectionTitle('Episode terakhir yang sudah ditonton'),
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Kurangi episode',
                    iconSize: 30,
                    onPressed: _episode > 0 ? () => setState(() => _episode--) : null,
                    icon: const Icon(Icons.remove_rounded, semanticLabel: 'Kurangi episode'),
                  ),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      label: _episode == 0 ? 'Belum mulai' : 'Episode $_episode',
                      excludeSemantics: true,
                      child: Center(
                        child: Pulse(
                          trigger: _episode,
                          child: Text(
                            _episode == 0 ? 'Belum mulai' : 'Eps $_episode',
                            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: c.accent),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Tambah episode',
                    iconSize: 30,
                    onPressed: () => setState(() => _episode++),
                    icon: const Icon(Icons.add_rounded, semanticLabel: 'Tambah episode'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const SectionTitle('Hari tayang'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      label: Semantics(label: dayLong(day), excludeSemantics: true, child: Text(dayShort(day))),
                      selected: _days.contains(day),
                      showCheckmark: true,
                      onSelected: (v) => setState(() => v ? _days.add(day) : _days.remove(day)),
                    ),
                ],
              ),
              Row(
                children: [
                  TextButton(onPressed: () => setState(() => _days = {1, 2, 3, 4, 5, 6, 7}), child: const Text('Setiap hari')),
                  TextButton(onPressed: hasDays ? () => setState(() => _days = {}) : null, child: const Text('Kosongkan')),
                ],
              ),
              const SizedBox(height: 8),
              _Tile(
                onTap: _pickTime,
                leading: Icon(Icons.schedule_rounded, color: c.accent, size: 36),
                title: 'Jam tayang ${clock(_minute)}',
                subtitle: 'Ketuk untuk mengubah jam',
                trailing: Icons.chevron_right_rounded,
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                value: _remind,
                onChanged: hasDays ? (v) => setState(() => _remind = v) : null,
                minTileHeight: 72,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: const Text('Ingatkan saya'),
                subtitle: Text(hasDays ? 'Notifikasi pada hari tayang' : 'Pilih hari tayang dulu'),
                secondary: Icon(Icons.notifications_active_outlined, color: c.accent, size: 32),
              ),
              if (_remind && hasDays) ...[
                const SizedBox(height: 8),
                Text('Bunyikan', style: theme.textTheme.titleSmall?.copyWith(color: c.muted)),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(minimumSize: const Size(0, kTouchTarget)),
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Tepat waktu')),
                    ButtonSegment(value: 10, label: Text('10 menit\nsebelumnya', textAlign: TextAlign.center)),
                    ButtonSegment(value: 30, label: Text('30 menit\nsebelumnya', textAlign: TextAlign.center)),
                  ],
                  selected: {_lead},
                  onSelectionChanged: (s) => setState(() => _lead = s.first),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _valid ? _save : null,
                icon: const Icon(Icons.check_rounded, size: 28),
                label: const Text('Simpan'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
              ),
              if (!_isNew) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Hapus drama'),
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.onTap, required this.leading, required this.title, this.subtitle, this.trailing});
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String? subtitle;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final theme = Theme.of(context);
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          color: c.surfaceHigh,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 76),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    leading,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: c.muted)),
                        ],
                      ),
                    ),
                    if (trailing != null) Icon(trailing, color: c.muted, size: 30),
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

/// Pilihan cepat: platform yang aplikasinya terpasang di perangkat ini.
class _PlatformChips extends StatelessWidget {
  const _PlatformChips({required this.selected, required this.onSelect});
  final String? selected;
  final void Function(String package, String label) onSelect;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final installed = installedPlatforms({for (final a in state.apps) a.package});
    if (installed.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (p, pkg) in installed)
          ChoiceChip(
            avatar: AppIcon(app: state.appOf(pkg), size: 24),
            label: Text(p.name),
            selected: selected == pkg,
            showCheckmark: false,
            labelStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: selected == pkg ? context.colors.onPrimary : context.colors.text),
            onSelected: (_) => onSelect(pkg, state.appOf(pkg)?.label ?? p.name),
          ),
      ],
    );
  }
}
