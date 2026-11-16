package com.ciptadusa.dracin_launcher

import android.accessibilityservice.AccessibilityService
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

    override fun onInterrupt() {}

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        step()
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

        @Volatile var instance: ForceStopService? = null
        @Volatile var current: Job? = null
    }
}
