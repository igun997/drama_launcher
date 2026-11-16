package com.ciptadusa.dracin_launcher

import android.accessibilityservice.AccessibilityService
import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.view.Display
import java.io.File
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.util.concurrent.CountDownLatch

/**
 * Android 14+ melarang aplikasi biasa menutup aplikasi lain (killBackgroundProcesses hanya
 * berlaku untuk dirinya sendiri). Satu-satunya jalan tanpa hak sistem adalah yang dilakukan
 * pengguna: Info aplikasi > "Paksa berhenti" > OK. Layanan aksesibilitas ini menekan kedua
 * tombol itu atas permintaan launcher, dan HANYA mendengarkan jendela Pengaturan sistem
 * (lihat force_stop_service.xml). Tidak membaca apa pun dari aplikasi lain.
 */
class ForceStopService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        if (instance === this) instance = null
        return super.onUnbind(intent)
    }

    /** Hampir seluruh titik contoh gelap sekali (rata-rata cahaya < 12 dari 255). */
    private fun isBlank(b: Bitmap): Boolean {
        var sum = 0L
        var n = 0
        val stepX = (b.width / 24).coerceAtLeast(1)
        val stepY = (b.height / 24).coerceAtLeast(1)
        var y = 0
        while (y < b.height) {
            var x = 0
            while (x < b.width) {
                val c = b.getPixel(x, y)
                sum += (((c shr 16) and 0xFF) * 299 + ((c shr 8) and 0xFF) * 587 + (c and 0xFF) * 114) / 1000
                n++
                x += stepX
            }
            y += stepY
        }
        return n == 0 || sum / n < 12
    }

    override fun onInterrupt() {}

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (current != null) {
            step()
            return
        }
        // Tidak sedang menutup aplikasi: baca judul tontonan dari WeTV/iQIYI (satu id tampilan saja).
        val pkg = event?.packageName?.toString() ?: return
        if (pkg in WATCH_TITLE_IDS) scheduleRead(pkg)
    }

    private val handler = Handler(Looper.getMainLooper())
    private var readRunnable: Runnable? = null
    private var lastThumbKey: String? = null
    private var lastThumbAt = 0L
    private var thumbTries = 0

    /**
     * Baca paling sering tiap 1,5 detik. Sengaja bukan "tunggu tenang": pemutar mengirim peristiwa
     * terus-menerus (bilah kemajuan), sehingga penundaan yang diulang tidak akan pernah jalan.
     */
    private fun scheduleRead(pkg: String) {
        if (readRunnable != null) return
        readRunnable = Runnable {
            readRunnable = null
            readTitle(pkg)
        }.also { handler.postDelayed(it, 1500) }
    }

    private fun readTitle(pkg: String) {
        val root = rootInActiveWindow ?: return
        try {
            if (root.packageName?.toString() != pkg) return
            val (titleId, anchorId) = WATCH_TITLE_IDS[pkg] ?: return
            // Halaman detail/pemutar memuat id jangkar (skor/jumlah episode); iklan dan beranda tidak.
            if (root.findAccessibilityNodeInfosByViewId("$pkg:id/$anchorId").isEmpty()) return
            val title = root.findAccessibilityNodeInfosByViewId("$pkg:id/$titleId")
                .firstNotNullOfOrNull { it.text?.toString()?.trim()?.takeIf { t -> t.length in 2..120 } } ?: return
            NowWatching.update(pkg, title)
            maybeThumbnail(pkg, title)
        } finally {
            root.recycle()
        }
    }

    /** Satu tangkapan layar kecil per tontonan (paling sering tiap 10 menit). */
    private fun maybeThumbnail(pkg: String, title: String) {
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.R) return
        val key = "$pkg|$title"
        val now = System.currentTimeMillis()
        if (key != lastThumbKey) {
            lastThumbKey = key
            thumbTries = 0
        } else if (NowWatching.thumbPath != null || thumbTries >= 4 || now - lastThumbAt < 15_000L) {
            return // sudah punya gambar, sudah mencoba 4 kali, atau terlalu cepat
        }
        thumbTries++
        lastThumbAt = now
        takeScreenshot(Display.DEFAULT_DISPLAY, mainExecutor, object : TakeScreenshotCallback {
            override fun onSuccess(result: ScreenshotResult) {
                try {
                    val hw = Bitmap.wrapHardwareBuffer(result.hardwareBuffer, result.colorSpace) ?: return
                    val soft = hw.copy(Bitmap.Config.ARGB_8888, false)
                    hw.recycle()
                    result.hardwareBuffer.close()
                    if (isBlank(soft)) {
                        // Layar video terlindungi/hitam: jangan simpan gambar kosong; dicoba lagi nanti.
                        Log.i(TAG, "thumbnail kosong (hitam), dilewati")
                        return
                    }
                    val w = 480
                    val scaled = Bitmap.createScaledBitmap(soft, w, (soft.height * w / soft.width.toFloat()).toInt().coerceAtLeast(1), true)
                    val dir = File(filesDir, "thumbs").apply { mkdirs() }
                    val file = File(dir, "${key.hashCode().toUInt().toString(16)}.jpg")
                    file.outputStream().use { scaled.compress(Bitmap.CompressFormat.JPEG, 80, it) }
                    // Pastikan masih tontonan yang sama sebelum dipasang.
                    if (NowWatching.title == title) NowWatching.thumbPath = file.absolutePath
                    Log.i(TAG, "thumbnail $title -> ${file.name} (${file.length() / 1024} KB)")
                } catch (e: Exception) {
                    Log.i(TAG, "thumbnail gagal: ${e.message}")
                }
            }

            override fun onFailure(errorCode: Int) {
                Log.i(TAG, "tangkapan layar ditolak: $errorCode")
            }
        })
    }

    /**
     * Satu langkah otomatisasi untuk pekerjaan yang sedang berjalan. Dipanggil dari peristiwa
     * aksesibilitas dan juga berkala oleh peminta, karena layar Info aplikasi bisa selesai
     * digambar tanpa peristiwa tambahan.
     */
    @Synchronized
    fun step() {
        val job = current ?: return
        val root = rootInActiveWindow
        if (root == null) {
            Log.i(TAG, "${job.packageName}: rootInActiveWindow null")
            return
        }
        try {
            if (root.packageName?.toString() != SETTINGS_PACKAGE) {
                Log.i(TAG, "${job.packageName}: jendela aktif ${root.packageName}, bukan Pengaturan")
                return
            }
            when (job.stage) {
                Stage.FIND_BUTTON -> {
                    // Pastikan ini halaman Info aplikasi milik paket yang dituju, bukan sisa halaman
                    // sebelumnya (tombolnya mati setelah aplikasi itu dihentikan).
                    if (!mentions(root, job.packageName, job.label)) {
                        Log.i(TAG, "${job.packageName}: menunggu halaman Info aplikasi yang tepat")
                        return
                    }
                    val button = findByLabel(root, FORCE_STOP_LABELS)
                    if (button == null) {
                        Log.i(TAG, "${job.packageName}: tombol belum ditemukan (anak=${root.childCount})")
                        return
                    }
                    if (!isActionable(button)) {
                        // Layar baru dibuka: tombol sempat mati sebelum datanya termuat. Baru dianggap
                        // "sudah berhenti" bila tetap mati beberapa pemeriksaan berturut-turut (~1,5 detik).
                        job.disabledSeen++
                        if (job.disabledSeen >= 5) {
                            Log.i(TAG, "${job.packageName}: tombol Paksa berhenti tetap nonaktif, dianggap sudah berhenti")
                            job.finish(true)
                        }
                        return
                    }
                    job.disabledSeen = 0
                    if (click(button)) {
                        Log.i(TAG, "${job.packageName}: Paksa berhenti ditekan")
                        job.stage = Stage.CONFIRM
                    }
                }
                Stage.CONFIRM -> {
                    // Hanya tombol dialog (OK/Ya); jangan salah menekan "Paksa berhenti" di halaman di belakangnya.
                    val ok = root.findAccessibilityNodeInfosByViewId("android:id/button1").firstOrNull()
                        ?: findByLabel(root, CONFIRM_LABELS, quiet = true)
                    if (ok == null) {
                        Log.i(TAG, "${job.packageName}: menunggu dialog konfirmasi")
                        return
                    }
                    if (click(ok)) {
                        Log.i(TAG, "${job.packageName}: dikonfirmasi")
                        job.finish(true)
                    }
                }
            }
        } finally {
            root.recycle()
        }
    }

    private fun canClick(n: AccessibilityNodeInfo): Boolean =
        n.isClickable || n.actionList.any { it.id == AccessibilityNodeInfo.ACTION_CLICK }

    /** Node itu atau leluhur terdekat yang bisa diklik (Compose tidak selalu menandai isClickable). */
    private fun clickTarget(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        var n: AccessibilityNodeInfo? = node
        var depth = 0
        while (n != null && depth < 8) {
            if (canClick(n)) return n
            n = n.parent
            depth++
        }
        return null
    }

    private fun describe(n: AccessibilityNodeInfo): String =
        "enabled=${n.isEnabled} clickable=${n.isClickable} klik=${canClick(n)} kelas=${n.className}"

    /** Tombol aktif bila ada target klik yang enabled. */
    private fun isActionable(node: AccessibilityNodeInfo): Boolean {
        val target = clickTarget(node)
        Log.i(TAG, "tombol: ${describe(node)}; target=${target?.let { describe(it) }}")
        return target != null && target.isEnabled
    }

    private fun click(node: AccessibilityNodeInfo): Boolean {
        val target = clickTarget(node) ?: return false
        return target.isEnabled && target.performAction(AccessibilityNodeInfo.ACTION_CLICK)
    }

    /** Ada teks di layar yang memuat ID paket atau nama aplikasi (judul/baris versi Info aplikasi). */
    private fun mentions(root: AccessibilityNodeInfo, pkg: String, label: String?): Boolean {
        fun walk(n: AccessibilityNodeInfo, depth: Int): Boolean {
            val t = n.text?.toString()
            if (t != null && (t.contains(pkg) || (label != null && t.equals(label, ignoreCase = true)))) return true
            if (depth > 40) return false
            for (i in 0 until n.childCount) {
                val c = n.getChild(i) ?: continue
                if (walk(c, depth + 1)) return true
            }
            return false
        }
        return walk(root, 0)
    }

    /** Cari node yang teks atau deskripsinya sama dengan salah satu [labels] (telusur seluruh pohon). */
    private fun findByLabel(root: AccessibilityNodeInfo, labels: List<String>, quiet: Boolean = false): AccessibilityNodeInfo? {
        val seen = ArrayList<String>()
        fun walk(n: AccessibilityNodeInfo, depth: Int): AccessibilityNodeInfo? {
            val t = n.text?.toString()?.trim()
            val d = n.contentDescription?.toString()?.trim()
            if (!t.isNullOrEmpty()) seen.add(t)
            if (!d.isNullOrEmpty()) seen.add("[$d]")
            if (labels.any { it.equals(t, ignoreCase = true) || it.equals(d, ignoreCase = true) }) return n
            if (depth > 40) return null
            for (i in 0 until n.childCount) {
                val c = n.getChild(i) ?: continue
                walk(c, depth + 1)?.let { return it }
            }
            return null
        }
        val found = walk(root, 0)
        if (found == null && !quiet) Log.i(TAG, "teks di layar: ${seen.take(60)}")
        return found
    }

    enum class Stage { FIND_BUTTON, CONFIRM }

    /** Satu pekerjaan: hentikan paksa satu paket. Selesai ditandai lewat [latch]. */
    class Job(val packageName: String, val label: String? = null) {
        @Volatile var stage = Stage.FIND_BUTTON
        @Volatile var ok = false
        @Volatile var disabledSeen = 0
        val latch = CountDownLatch(1)

        fun finish(success: Boolean) {
            ok = success
            latch.countDown()
        }
    }

    companion object {
        const val TAG = "ForceStop"
        const val SETTINGS_PACKAGE = "com.android.settings"
        private val FORCE_STOP_LABELS = listOf("Paksa berhenti", "Hentikan paksa", "Berhenti paksa", "Force stop", "Force Stop")
        private val CONFIRM_LABELS = listOf("Oke", "OK", "Ya", "Yes", "Okay")

        /** id judul dan id jangkar (halaman detail/pemutar) tiap aplikasi tontonan yang dikenal. */
        val WATCH_TITLE_IDS = mapOf(
            "com.iqiyi.i18n" to Pair("tv_title", "tv_score"),
            "com.tencent.qqlivei18n" to Pair("titleTextView", "video_rating_tv"),
        )

        @Volatile var instance: ForceStopService? = null
        @Volatile var current: Job? = null
    }
}
