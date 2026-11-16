# Drama Launcher (Dracin Launcher)

Layar utama (launcher) Android yang minimalis untuk penonton drama Tiongkok. Pribadi, dibuat oleh [PT Cipta Dua Saudara](https://www.ciptadusa.com).

- **Lanjut nonton**: kartu per drama (Dracin atau Drakor) dengan tombol besar "Nonton Eps N" dan "Eps N selesai" (+1, bisa diurungkan). Bila drama punya tautan, "Nonton" membuka langsung halaman drama di aplikasinya.
- **Mode Dracin / Drakor**: satu ketukan menyaring daftar sekaligus memasang paket tema yang sama (lentera merah-emas atau sakura pink-biru malam, dengan kelopak jatuh). Membuka drama jenis lain memindahkan mode.
- **Riwayat tontonan**: buka WeTV/iQIYI/dll. dari sini lalu kembali, launcher bertanya "Tadi nonton apa?" (Eps selesai / baru sebagian). Riwayat per hari, ringkasan 7 hari per jenis, dan tombol Lanjut.
- **Catat otomatis dari WeTV dan iQIYI** (opsional, di Pengaturan): dengan layanan Aksesibilitas aktif, judul yang tampil di halaman detail/pemutar dibaca dan dicatat ke riwayat bersama satu tangkapan layar kecil (bingkai gelap/terlindungi dibuang). Diuji di perangkat: kedua aplikasi tidak memasang MediaSession maupun notifikasi saat memutar, jadi jalur itu tidak bisa dipakai. Hanya layar kedua aplikasi itu yang dibaca; tidak ada data keluar perangkat. Putar di jendela PiP tidak dihitung sebagai durasi.
- **WeTV, iQIYI, Viu, Vidio, DramaBox, ReelShort, YouTube**: tautan dikenali dan aplikasinya dipilih otomatis; tombol Bagikan di aplikasi itu bisa mengirim judul + tautan langsung ke launcher ini. Tidak ada API resmi untuk membaca data/riwayat dari platform tersebut, jadi riwayat dicatat dari penggunaan lewat launcher.
- **Pengingat tayang**: hari dan jam tayang per drama, dibunyikan 0/10/30 menit sebelumnya, tahan restart.
- **Istirahat mata** (1 sampai 2,5 jam setelah membuka aplikasi tontonan) dan **waktu tidur** opsional.
- **Dock melayang** (aplikasi tontonan + pintasan + Aktif + Semua) dan gestur tanpa tombol: geser ke atas di area dock = semua aplikasi, geser pelan lalu lepas di dock = aplikasi aktif, tarik daftar ke bawah dari puncak = kembali ke beranda, tarik ke bawah dari bagian jam = notifikasi (menggulir daftar drama tidak memicunya). Tombol **?** di beranda menjelaskan semuanya. Tombol Home/gestur sistem selalu kembali ke beranda.
- **Aplikasi aktif** (dipakai 6 jam terakhir) dengan Tutup per aplikasi, geser-untuk-tutup, dan **Bersihkan RAM** (mengukur RAM kosong sebelum/sesudah). Menutup aplikasi (Android 14+ melarang cara langsung) lewat dua cara: **Shizuku** (senyap, tanpa layar apa pun; dimulai lewat Debugging nirkabel/adb, ulangi tiap restart tablet) atau layanan **Aksesibilitas** "Tutup Aplikasi" yang menekan Paksa berhenti dan Oke di Info aplikasi (layar Pengaturan tampil sebentar). Tanpa keduanya halaman ini hanya memantau (RAM dan daftar aplikasi).
- Tanpa internet, tanpa iklan. Data hanya di perangkat (SharedPreferences).

## Aksesibilitas

- Target sentuh >= 56 dp, diuji dengan `androidTapTargetGuideline` dan `labeledTapTargetGuideline`.
- Semua ikon-tombol punya nama untuk TalkBack; status tidak hanya dibedakan lewat warna.
- Kontras tema gelap/terang dihitung >= 4.5:1 (teks utama >= 7:1).
- Ukuran tulisan (Biasa/Besar/Sangat besar) dikalikan dengan skala teks sistem; tata letak mengikuti isi, tidak ada tinggi tetap.
- Mengikuti "Hapus animasi" Android: semua gerak berhenti dan konten langsung tampil.

## Gerak

Hanya `opacity`/`transform` (tanpa layout): tampil berurutan, tekan-menyusut, lentera "bernapas", latar bergeser pelan, lonceng bergoyang saat tayang < 1 jam, angka episode berganti halus, transisi halaman. Animasi berulang berhenti saat halaman tertutup atau "hapus animasi" aktif.

## Performa

- Ikon aplikasi dirender di thread latar (128 px), di-cache per `package:lastUpdateTime`, dan memakai satu `ImageProvider` per aplikasi.
- Zona waktu, daftar aplikasi, dan pengingat disiapkan setelah frame pertama.
- Dependensi Dart: `flutter_local_notifications`, `shared_preferences`, `timezone` (data 10 tahun), `material_ui`. Native: Shizuku API + HiddenApiBypass (hanya untuk mode senyap).
- Rilis: R8 + `shrinkResources`, gambar WebP.

## Build (remote, bukan di komputer ini)

Semua build dan tes berjalan di sandbox lewat [rflutter](https://github.com/igun997/rflutter) (`rflutter.toml`, Flutter 3.50.0):

```
rflutter analyze
rflutter test
rflutter build apk --release --target-platform android-arm64
rflutter --install build apk --release        # pasang ke tablet lewat adb
rflutter run                                  # hot reload di tablet (jalankan sendiri di terminal)
rflutter remote down                          # jeda sandbox (bangun sendiri saat dipakai)
```

## Ikon dan gambar

`python3 tools/buat_ikon.py` membuat ulang semua ikon dari `art/`: mipmap Android (legacy, bulat, adaptif, monokrom/tema), favicon (`.ico` + `.png`), ikon web/PWA (biasa + maskable), `apple-touch-icon`, gambar bagikan OG, ikon Play Store 512 px dan grafis fitur 1024x500 (`store/`), serta aset Flutter WebP (`assets/images/`).

Master gambar dibuat dengan `python3 tools/genimg.py OUT.png "prompt" --env .env` (berkas `.env` berisi `URL` dan `KEY` endpoint gambar kompatibel OpenAI; tidak pernah di-commit). Ilustrasi di `art/` dan `assets/images/` dihasilkan AI.

## Nightly dan rilis bertanda tangan

Build malam otomatis dari `main` (GitHub Actions, `.github/workflows/nightly.yml`) diterbitkan sebagai pra-rilis [`nightly`](../../releases/tag/nightly), APK per ABI + `SHA256SUMS.txt`, ditandatangani kunci rilis proyek. Pasang yang `arm64-v8a` untuk kebanyakan perangkat.

Untuk membangun sendiri dengan kunci Anda: buat keystore, isi `android/key.properties` (`storePassword`, `keyPassword`, `keyAlias`, `storeFile`) dan taruh `.jks` di `android/app/`; keduanya diabaikan git. Tanpa berkas itu build rilis memakai kunci debug. Secrets Actions yang dibutuhkan: `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.

Paket: `com.ciptadusa.dracin_launcher`. Lisensi: MIT.

## Izin khusus

- **Akses penggunaan** (Pengaturan > Akses penggunaan): daftar aplikasi aktif.
- **Shizuku** (opsional, mode senyap): pasang Shizuku, mulai lewat Debugging nirkabel/adb, lalu "Izinkan" di layar Aplikasi aktif.
- **Aksesibilitas "Tutup Aplikasi & Catat Tontonan"** (opsional): hanya mendengarkan jendela Pengaturan sistem (tutup aplikasi) dan WeTV/iQIYI (judul tontonan + tangkapan layar kecil).
- Pengingat tepat waktu: notifikasi + "Alarm & pengingat".
