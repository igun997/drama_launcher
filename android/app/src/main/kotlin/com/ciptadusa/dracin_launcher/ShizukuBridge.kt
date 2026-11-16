package com.ciptadusa.dracin_launcher

import android.content.Context
import android.content.pm.PackageManager
import android.os.IBinder
import android.os.Process
import org.lsposed.hiddenapibypass.HiddenApiBypass
import rikka.shizuku.Shizuku
import rikka.shizuku.ShizukuBinderWrapper
import rikka.shizuku.SystemServiceHelper

/**
 * Menutup aplikasi tanpa membuka layar apa pun, lewat Shizuku (hak "shell" seperti adb).
 *
 * Android 14+ melarang aplikasi biasa menutup aplikasi lain, dan izin FORCE_STOP_PACKAGES
 * tidak bisa diberikan ke aplikasi biasa. Shizuku menjalankan layanan dengan hak shell
 * (dimulai sekali lewat Debugging nirkabel/adb), dan di sanalah forceStopPackage diizinkan.
 */
object ShizukuBridge {
    const val SHIZUKU_PACKAGE = "moe.shizuku.privileged.api"
    private const val REQUEST_CODE = 4217

    /** Nilai ini dikirim ke Dart: urutannya harus sama dengan enum SilentStatus. */
    const val NOT_INSTALLED = 0
    const val NOT_RUNNING = 1
    const val NEEDS_PERMISSION = 2
    const val READY = 3

    private var bypassed = false

    fun status(context: Context): Int {
        val installed = runCatching { context.packageManager.getPackageInfo(SHIZUKU_PACKAGE, 0) }.isSuccess
        if (!installed) return NOT_INSTALLED
        if (!runCatching { Shizuku.pingBinder() }.getOrDefault(false)) return NOT_RUNNING
        if (runCatching { Shizuku.isPreV11() }.getOrDefault(true)) return NOT_RUNNING
        return if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) READY else NEEDS_PERMISSION
    }

    fun requestPermission() {
        runCatching { Shizuku.requestPermission(REQUEST_CODE) }
    }

    /** forceStopPackage(pkg, userId) pada IActivityManager, dipanggil dengan identitas Shizuku. */
    fun forceStop(pkg: String): Boolean = runCatching {
        if (!bypassed) {
            HiddenApiBypass.addHiddenApiExemptions("L")
            bypassed = true
        }
        val binder: IBinder = ShizukuBinderWrapper(SystemServiceHelper.getSystemService("activity"))
        val stub = Class.forName("android.app.IActivityManager\$Stub")
        val am = stub.getMethod("asInterface", IBinder::class.java).invoke(null, binder)!!
        am.javaClass.getMethod("forceStopPackage", String::class.java, Int::class.javaPrimitiveType)
            .invoke(am, pkg, Process.myUid() / 100000)
        true
    }.getOrDefault(false)
}
