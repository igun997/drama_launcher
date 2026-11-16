package com.ciptadusa.dracin_launcher

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.role.RoleManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Telephony
import android.telecom.TelecomManager
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.TimeZone
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * Jembatan ke Android untuk launcher: daftar aplikasi, buka aplikasi, zona waktu.
 * Daftar dan ikon dihitung di thread latar dan di-cache sampai ada aplikasi
 * yang dipasang/dihapus/diperbarui.
 */
class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val iconCache = ConcurrentHashMap<String, ByteArray>()
    private var channel: MethodChannel? = null

    /** Teks dari tombol Bagikan aplikasi lain, menunggu diambil Dart. */
    @Volatile
    private var pendingShare: String? = null

    @Volatile
    private var cachedApps: List<Map<String, Any>>? = null

    private val packageReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            cachedApps = null
            channel?.invokeMethod("packagesChanged", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "getApps" -> loadApps(result)
                "launch" -> result.success(launch(call.argument<String>("package")))
                "openLink" -> result.success(openLink(call.argument<String>("package"), call.argument<String>("url")))
                "takeSharedText" -> {
                    val text = pendingShare
                    pendingShare = null
                    result.success(text)
                }
                "openAppSettings" -> result.success(openAppSettings(call.argument<String>("package")))
                "openHomeSettings" -> result.success(openHomeSettings())
                "isDefaultLauncher" -> result.success(isDefaultLauncher())
                "isGestureNavigation" -> result.success(isGestureNavigation())
                "openGestureSettings" -> result.success(openGestureSettings())
                "expandNotifications" -> result.success(expandNotifications())
                "hasUsageAccess" -> result.success(hasUsageAccess())
                "openUsageAccessSettings" -> result.success(openUsageAccessSettings())
                "activeApps" -> result.success(activeApps())
                "memoryInfo" -> result.success(memoryInfo())
                "restartApp" -> {
                    result.success(true)
                    restartApp()
                }
                "silentStatus" -> result.success(ShizukuBridge.status(this))
                "requestSilent" -> {
                    ShizukuBridge.requestPermission()
                    result.success(true)
                }
                "openShizukuStore" -> result.success(openShizukuStore())
                "nowWatching" -> {
                    val since = call.argument<Number>("sinceMs")?.toLong() ?: 0L
                    result.success(NowWatching.snapshot(since))
                }
                "clearNowWatching" -> {
                    NowWatching.clear()
                    result.success(true)
                }
                "forceStopEnabled" -> result.success(forceStopEnabled())
                "openAccessibilitySettings" -> result.success(openAccessibilitySettings())
                "forceStop" -> forceStop(call.argument<List<String>>("packages") ?: emptyList(), result)
                "timeZone" -> result.success(TimeZone.getDefault().id)
                else -> result.notImplemented()
            }
        }
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addDataScheme("package")
        }
        registerReceiver(packageReceiver, filter)
    }

    override fun onDestroy() {
        runCatching { unregisterReceiver(packageReceiver) }
        worker.shutdown()
        super.onDestroy()
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        captureShare(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (captureShare(intent)) {
            channel?.invokeMethod("shared", null)
        } else if (intent.hasCategory(Intent.CATEGORY_HOME)) {
            channel?.invokeMethod("home", null)
        }
    }

    private fun captureShare(intent: Intent?): Boolean {
        if (intent?.action != Intent.ACTION_SEND || intent.type?.startsWith("text/") != true) return false
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)
        if (text.isNullOrBlank()) return false
        pendingShare = text
        return true
    }

    private fun loadApps(result: MethodChannel.Result) {
        cachedApps?.let {
            result.success(it)
            return
        }
        worker.execute {
            val apps = runCatching { queryApps() }
            main.post {
                apps.onSuccess {
                    cachedApps = it
                    result.success(it)
                }.onFailure { result.error("apps", it.message, null) }
            }
        }
    }

    private fun queryApps(): List<Map<String, Any>> {
        val pm = packageManager
        val query = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val seen = HashSet<String>()
        val out = ArrayList<Map<String, Any>>()
        for (info in pm.queryIntentActivities(query, 0)) {
            val pkg = info.activityInfo.packageName
            if (pkg == packageName || !seen.add(pkg)) continue
            val updated = runCatching { pm.getPackageInfo(pkg, 0).lastUpdateTime }.getOrDefault(0L)
            val key = "$pkg:$updated"
            val icon = iconCache.getOrPut(key) { render(info.loadIcon(pm)) }
            out.add(mapOf("package" to pkg, "label" to info.loadLabel(pm).toString(), "icon" to icon))
        }
        out.sortBy { (it["label"] as String).lowercase() }
        return out
    }

    private fun render(drawable: android.graphics.drawable.Drawable): ByteArray {
        val size = ICON_PX
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        val bytes = ByteArrayOutputStream(8 * 1024)
        bmp.compress(Bitmap.CompressFormat.PNG, 100, bytes)
        bmp.recycle()
        return bytes.toByteArray()
    }

    private fun launch(pkg: String?): Boolean {
        if (pkg == null) return false
        val intent = packageManager.getLaunchIntentForPackage(pkg) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return runCatching { startActivity(intent) }.isSuccess
    }

    /** Membuka tautan langsung di dalam aplikasi tertentu (App Link / deep link), mis. halaman drama. */
    private fun openLink(pkg: String?, url: String?): Boolean {
        if (pkg == null || url.isNullOrBlank()) return false
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).setPackage(pkg).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return runCatching { startActivity(intent) }.isSuccess
    }

    private fun openAppSettings(pkg: String?): Boolean {
        if (pkg == null) return false
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", pkg, null))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return runCatching { startActivity(intent) }.isSuccess
    }

    private fun openHomeSettings(): Boolean {
        val intent = Intent(Settings.ACTION_HOME_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return runCatching { startActivity(intent) }.isSuccess
    }

    /** Navigasi sistem: 0 = tiga tombol, 1 = dua tombol, 2 = gestur penuh. */
    private fun isGestureNavigation(): Boolean =
        Settings.Secure.getInt(contentResolver, "navigation_mode", 0) == 2

    private fun openGestureSettings(): Boolean {
        val candidates = listOf(
            Intent().setClassName("com.android.settings", "com.android.settings.Settings\$GestureNavigationSettingsActivity"),
            Intent("android.settings.SYSTEM_NAVIGATION_SETTINGS"),
            Intent(Settings.ACTION_SETTINGS),
        )
        for (intent in candidates) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (runCatching { startActivity(intent) }.isSuccess) return true
        }
        return false
    }

    /** Membuka bilah notifikasi (API tersembunyi StatusBarManager, aman dipanggil dengan runCatching). */
    private fun expandNotifications(): Boolean = runCatching {
        val service = getSystemService("statusbar")
        service!!.javaClass.getMethod("expandNotificationsPanel").invoke(service)
        true
    }.getOrDefault(false)

    // ---- Aplikasi aktif, tutup aplikasi, bersihkan RAM ----

    private fun hasUsageAccess(): Boolean {
        val ops = getSystemService(AppOpsManager::class.java) ?: return false
        val mode = ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageAccessSettings(): Boolean {
        val withPackage = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS, Uri.fromParts("package", packageName, null))
        val plain = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        for (intent in listOf(withPackage, plain)) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (runCatching { startActivity(intent) }.isSuccess) return true
        }
        return false
    }

    /**
     * Aplikasi yang dipakai dalam 6 jam terakhir (dari peristiwa penggunaan), terbaru dulu.
     * Android tidak mengizinkan aplikasi biasa melihat proses lain, jadi "aktif" berarti baru dipakai.
     */
    private fun activeApps(): List<Map<String, Any>> {
        if (!hasUsageAccess()) return emptyList()
        val usm = getSystemService(UsageStatsManager::class.java) ?: return emptyList()
        val end = System.currentTimeMillis()
        val events = usm.queryEvents(end - 6 * 3600_000L, end) ?: return emptyList()
        val last = HashMap<String, Long>()
        val foreground = HashMap<String, Boolean>()
        val e = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            val pkg = e.packageName ?: continue
            if (pkg == packageName) continue
            when (e.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    last[pkg] = e.timeStamp
                    foreground[pkg] = true
                }
                UsageEvents.Event.ACTIVITY_PAUSED, UsageEvents.Event.ACTIVITY_STOPPED -> {
                    last[pkg] = maxOf(last[pkg] ?: 0L, e.timeStamp)
                    foreground[pkg] = false
                }
            }
        }
        return last.entries.sortedByDescending { it.value }.take(40).map {
            mapOf("package" to it.key, "lastUsedMs" to it.value, "foreground" to (foreground[it.key] ?: false))
        }
    }

    private fun memoryInfo(): Map<String, Long> {
        val am = getSystemService(ActivityManager::class.java)
        val info = ActivityManager.MemoryInfo()
        am.getMemoryInfo(info)
        return mapOf("avail" to info.availMem, "total" to info.totalMem)
    }

    /** Peladen yang tidak boleh ditutup massal: keyboard, telepon, SMS, dan launcher ini. */
    private fun protectedPackages(): Set<String> {
        val out = HashSet<String>()
        out.add(packageName)
        out.add(ShizukuBridge.SHIZUKU_PACKAGE) // menutupnya mematikan mode senyap
        runCatching {
            Settings.Secure.getString(contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD)
                ?.substringBefore('/')?.let { out.add(it) }
        }
        runCatching { getSystemService(TelecomManager::class.java)?.defaultDialerPackage?.let { out.add(it) } }
        runCatching { Telephony.Sms.getDefaultSmsPackage(this)?.let { out.add(it) } }
        return out
    }

    /**
     * Mulai ulang penuh (proses baru): dipakai setelah mengaktifkan layanan Aksesibilitas
     * atau izin khusus supaya semuanya terbaca bersih. Aktivitas baru diluncurkan dulu,
     * lalu proses ini dimatikan.
     */
    private fun restartApp() {
        val intent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        main.postDelayed({
            runCatching { startActivity(intent) }
            main.postDelayed({ Process.killProcess(Process.myPid()) }, 250)
        }, 150)
    }

    /** Pasang Shizuku: Play Store bila ada, selain itu halaman unduhannya. */
    private fun openShizukuStore(): Boolean {
        val candidates = listOf(
            Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=${ShizukuBridge.SHIZUKU_PACKAGE}")),
            Intent(Intent.ACTION_VIEW, Uri.parse("https://shizuku.rikka.app/download/")),
        )
        for (intent in candidates) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (runCatching { startActivity(intent) }.isSuccess) return true
        }
        return false
    }

    private fun isStopped(pkg: String): Boolean = runCatching {
        packageManager.getApplicationInfo(pkg, 0).flags and android.content.pm.ApplicationInfo.FLAG_STOPPED != 0
    }.getOrDefault(false)

    private fun forceStopEnabled(): Boolean {
        val enabled = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        val me = "$packageName/${ForceStopService::class.java.name}"
        return enabled.split(':').any { it.equals(me, ignoreCase = true) } && ForceStopService.instance != null
    }

    private fun openAccessibilitySettings(): Boolean {
        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return runCatching { startActivity(intent) }.isSuccess
    }

    /**
     * Menghentikan paksa tiap paket lewat Info aplikasi (ditekan oleh [ForceStopService]),
     * satu per satu, lalu membawa launcher kembali ke depan dan mengukur memori kosong.
     */
    private fun forceStop(packages: List<String>, result: MethodChannel.Result) {
        val silent = ShizukuBridge.status(this) == ShizukuBridge.READY
        if (!silent && !forceStopEnabled()) {
            result.error("service_off", "Belum ada cara menutup aplikasi yang aktif", null)
            return
        }
        val skip = protectedPackages()
        if (silent) {
            // Tanpa layar apa pun: setiap aplikasi dihentikan langsung lewat Shizuku.
            worker.execute {
                val before = memoryInfo()["avail"] ?: 0L
                val targets = packages.filter { it !in skip }
                val stopped = ArrayList<String>()
                for ((index, pkg) in targets.withIndex()) {
                    val label = runCatching { packageManager.getApplicationInfo(pkg, 0).loadLabel(packageManager).toString() }.getOrDefault(pkg)
                    main.post { channel?.invokeMethod("closeProgress", mapOf("done" to index, "total" to targets.size, "label" to label)) }
                    if (ShizukuBridge.forceStop(pkg)) stopped.add(pkg)
                }
                Thread.sleep(900)
                val after = memoryInfo()
                main.post {
                    result.success(
                        mapOf(
                            "closed" to stopped.size,
                            "stopped" to stopped,
                            "freed" to ((after["avail"] ?: 0L) - before),
                            "avail" to (after["avail"] ?: 0L),
                            "total" to (after["total"] ?: 0L),
                        ),
                    )
                }
            }
            return
        }
        worker.execute {
            val before = memoryInfo()["avail"] ?: 0L
            val stoppedPackages = ArrayList<String>()
            val targets = packages.filter { it !in skip }
            for ((index, pkg) in targets.withIndex()) {
                val label = runCatching { packageManager.getApplicationInfo(pkg, 0).loadLabel(packageManager).toString() }.getOrDefault(pkg)
                main.post {
                    channel?.invokeMethod("closeProgress", mapOf("done" to index, "total" to targets.size, "label" to label))
                }
                // Sudah berhenti (belum dibuka lagi sejak Paksa berhenti): tidak perlu membuka layar apa pun.
                if (isStopped(pkg)) {
                    stoppedPackages.add(pkg)
                    continue
                }
                val job = ForceStopService.Job(pkg, label)
                ForceStopService.current = job
                main.post {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", pkg, null))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK or Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS)
                    runCatching { startActivity(intent) }.onFailure { job.finish(false) }
                }
                // Layar Info aplikasi mungkin selesai digambar tanpa peristiwa baru: periksa berkala.
                val deadline = System.currentTimeMillis() + 8000
                while (System.currentTimeMillis() < deadline && !job.latch.await(300, java.util.concurrent.TimeUnit.MILLISECONDS)) {
                    ForceStopService.instance?.step()
                }
                if (job.ok) stoppedPackages.add(pkg)
                ForceStopService.current = null
            }
            // Kembali ke launcher. Dari latar belakang, startActivity bisa ditolak sistem; aksi
            // "Home" dari layanan Aksesibilitas selalu diizinkan dan menuju launcher ini bila itu layar utama.
            main.postDelayed({
                ForceStopService.instance?.performGlobalAction(android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_HOME)
                val back = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                runCatching { startActivity(back) }
            }, 400)
            Thread.sleep(900)
            val after = memoryInfo()
            main.post {
                result.success(
                    mapOf(
                        "closed" to stoppedPackages.size,
                        "stopped" to stoppedPackages,
                        "freed" to ((after["avail"] ?: 0L) - before),
                        "avail" to (after["avail"] ?: 0L),
                        "total" to (after["total"] ?: 0L),
                    ),
                )
            }
        }
    }

    private fun isDefaultLauncher(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roles = getSystemService(RoleManager::class.java)
            if (roles != null && roles.isRoleAvailable(RoleManager.ROLE_HOME)) {
                return roles.isRoleHeld(RoleManager.ROLE_HOME)
            }
        }
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val resolved = packageManager.resolveActivity(home, PackageManager.MATCH_DEFAULT_ONLY)
        return resolved?.activityInfo?.packageName == packageName
    }

    companion object {
        const val CHANNEL = "com.ciptadusa.dracin/launcher"
        const val ICON_PX = 128
    }
}
