/// Platform tontonan yang dikenal: dipakai untuk mengenali tautan dan memilih aplikasinya.
/// Tidak ada API resmi untuk mengambil data dari platform ini; yang dilakukan hanyalah
/// membuka tautan yang dibagikan pengguna langsung di aplikasinya.
class WatchPlatform {
  const WatchPlatform({required this.name, required this.hosts, required this.packages});
  final String name;

  /// Domain tautan bagikan (termasuk subdomain).
  final List<String> hosts;

  /// ID paket Android yang mungkin terpasang, urut prioritas.
  final List<String> packages;
}

const platforms = [
  WatchPlatform(name: 'WeTV', hosts: ['wetv.vip', 'wetv.com'], packages: ['com.tencent.qqlivei18n']),
  WatchPlatform(name: 'iQIYI', hosts: ['iq.com', 'iqiyi.com'], packages: ['com.iqiyi.i18n', 'com.qiyi.video']),
  WatchPlatform(name: 'Viu', hosts: ['viu.com', 'viu.tv'], packages: ['com.vuclip.viu']),
  WatchPlatform(name: 'Vidio', hosts: ['vidio.com'], packages: ['com.vidio.android']),
  WatchPlatform(name: 'DramaBox', hosts: ['dramaboxapp.com', 'dramabox.com'], packages: ['com.storymatrix.drama']),
  WatchPlatform(name: 'ReelShort', hosts: ['reelshort.com'], packages: ['com.newleaf.app.android.victor']),
  WatchPlatform(name: 'YouTube', hosts: ['youtube.com', 'youtu.be'], packages: ['com.google.android.youtube']),
];

/// Host dari [url] bila itu tautan http(s) yang valid, selain itu null.
String? hostOf(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) return null;
  return uri.host.toLowerCase();
}

bool isValidLink(String url) => hostOf(url) != null;

WatchPlatform? platformForUrl(String url) {
  final host = hostOf(url);
  if (host == null) return null;
  for (final p in platforms) {
    if (p.hosts.any((h) => host == h || host.endsWith('.$h'))) return p;
  }
  return null;
}

/// Paket pertama dari [platform] yang terpasang, atau null.
String? installedPackage(WatchPlatform platform, Set<String> installed) {
  for (final p in platform.packages) {
    if (installed.contains(p)) return p;
  }
  return null;
}

/// Platform yang paketnya terpasang, untuk pilihan cepat di editor.
List<(WatchPlatform, String)> installedPlatforms(Set<String> installed) => [
      for (final p in platforms)
        if (installedPackage(p, installed) case final pkg?) (p, pkg),
    ];

/// Hasil membaca teks dari tombol Bagikan.
class SharedDrama {
  const SharedDrama({this.title, this.link});
  final String? title;
  final String? link;
}

final _urlRe = RegExp(r'https?://[^\s<>"]+');
final _quoted = RegExp('["\u201C\u201D\u2018\u2019\u00AB\u300A\u300C]([^"\u201C\u201D\u2018\u2019\u00BB\u300B\u300D]{2,120})["\u201C\u201D\u2018\u2019\u00BB\u300B\u300D]');

/// Membaca judul dan tautan dari teks bagikan, mis.
/// `Tonton "Love Story" di WeTV https://wetv.vip/id/play/abc` -> judul "Love Story".
/// Pengguna tetap bisa mengubah hasilnya di editor.
SharedDrama parseShare(String text) {
  final m = _urlRe.firstMatch(text);
  String? link;
  var rest = text;
  if (m != null) {
    link = m.group(0)!.replaceAll(RegExp(r'[).,;!]+$'), '');
    rest = text.replaceRange(m.start, m.end, ' ');
  }
  String? title;
  final q = _quoted.firstMatch(rest);
  if (q != null) {
    title = q.group(1)!.trim();
  } else {
    var line = rest.split('\n').map((l) => l.trim()).firstWhere((l) => l.isNotEmpty, orElse: () => '');
    line = line
        .replaceAll(RegExp(r'\b(watch|tonton|nonton|check out|lihat|share|bagikan)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(on|di|at|di aplikasi)\s+(wetv|iqiyi|iq|viu|vidio|dramabox|reelshort|youtube)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(wetv|iqiyi|viu|vidio|dramabox|reelshort|youtube)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[|\u2013\u2014\-:]+\s*$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (line.length >= 2) title = line.length > 120 ? line.substring(0, 120) : line;
  }
  return SharedDrama(title: title, link: link);
}
