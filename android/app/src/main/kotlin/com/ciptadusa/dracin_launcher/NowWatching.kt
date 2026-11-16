package com.ciptadusa.dracin_launcher

/**
 * Judul tontonan terakhir yang terbaca dari WeTV/iQIYI oleh layanan Aksesibilitas
 * (hanya teks judul + satu tangkapan layar kecil). Disimpan di memori proses ini; Dart mengambilnya
 * saat pengguna kembali ke launcher.
 */
object NowWatching {
    @Volatile var packageName: String? = null
    @Volatile var title: String? = null
    @Volatile var thumbPath: String? = null
    @Volatile var seenAtMs: Long = 0

    @Synchronized
    fun update(pkg: String, newTitle: String) {
        if (pkg != packageName || newTitle != title) thumbPath = null // tontonan baru: gambar lama tidak berlaku
        packageName = pkg
        title = newTitle
        seenAtMs = System.currentTimeMillis()
    }

    @Synchronized
    fun snapshot(sinceMs: Long): Map<String, Any?>? {
        val t = title ?: return null
        if (seenAtMs < sinceMs) return null
        return mapOf("package" to packageName, "title" to t, "thumb" to thumbPath, "seenAtMs" to seenAtMs)
    }

    @Synchronized
    fun clear() {
        packageName = null
        title = null
        thumbPath = null
        seenAtMs = 0
    }
}
