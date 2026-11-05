package com.vvtech.phone_agent.ota

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import org.json.JSONObject
import java.io.File
import java.io.FileNotFoundException
import java.security.MessageDigest
import java.util.UUID

/** All callers serialize on LOCK, including across Flutter engine recreation. */
class UpdateDownloadStore(private val context: Context) {
    private val manager = context.getSystemService(DownloadManager::class.java)
    private val preferences = context.getSharedPreferences("flutter_ota_jobs_v1", Context.MODE_PRIVATE)

    data class Job(val scope: String, val key: String, val id: Long, val release: UpdateRelease,
        val forceUpdate: Boolean = false, val releaseNotes: String = "",
        val installReceipt: UpdateInstallReceipt? = null)

    fun peek(scope: String): Map<String, Any?>? {
        val job = read(scope) ?: return null
        @Suppress("DEPRECATION")
        val installed = context.packageManager.getPackageInfo(context.packageName, 0)
        val receipt = job.installReceipt
        if (receipt != null && installed.lastUpdateTime > receipt.previousUpdateTime) {
            val apk = File(installed.applicationInfo?.sourceDir ?: error("Missing installed APK"))
            val digest = MessageDigest.getInstance("SHA-256")
            apk.inputStream().use { input ->
                val buffer = ByteArray(65536)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    digest.update(buffer, 0, count)
                }
            }
            val hash = digest.digest().joinToString("") { "%02x".format(it) }
            if (receipt.completed(installed.lastUpdateTime, hash)) { cancel(job); return null }
        }
        val release = job.release
        return mapOf("packageName" to release.packageName, "versionName" to release.versionName,
            "versionCode" to release.versionCode, "fileSize" to release.fileSize,
            "checksumSha256" to release.checksum, "forceUpdate" to job.forceUpdate,
            "releaseNotes" to job.releaseNotes)
    }

    fun restore(scope: String, release: UpdateRelease): Map<String, Any?>? {
        val job = read(scope) ?: return null
        return if (job.release == release) snapshot(job) else null
    }

    fun begin(scope: String, release: UpdateRelease, values: Map<*, *>): Map<String, Any?> {
        val forceUpdate = values["forceUpdate"] as? Boolean ?: false
        val releaseNotes = (values["releaseNotes"] as? String ?: "").take(20000)
        // Re-attach even when a previous channel reply was lost; never duplicate enqueue.
        read(scope)?.let { old ->
            if (old.release == release && snapshot(old)["status"] != "failed") {
                save(old.copy(forceUpdate = forceUpdate, releaseNotes = releaseNotes))
                return snapshot(old)
            }
        }
        val uri = Uri.parse(values["apkUrl"] as? String ?: error("Missing URL"))
        require(uri.scheme in setOf("https", "http") && !uri.host.isNullOrBlank())
        require(uri.userInfo == null && uri.fragment == null)
        val headers = values["downloadHeaders"] as? Map<*, *> ?: emptyMap<Any, Any>()
        val request = DownloadManager.Request(uri)
            .setTitle("PhoneAgent 应用更新")
            .setMimeType("application/vnd.android.package-archive")
            .setAllowedOverMetered(true).setAllowedOverRoaming(true)
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
        headers.forEach { (name, value) ->
            require(name is String && name.matches(Regex("[!#$%&'*+.^_`|~0-9A-Za-z-]+")))
            require(value is String && !value.contains('\r') && !value.contains('\n'))
            request.addRequestHeader(name, value)
        }
        read(scope)?.let(::cancel)
        val job = Job(scope, UUID.randomUUID().toString(), 0, release, forceUpdate, releaseNotes)
        val target = downloadFile(job)
        request.setDestinationUri(Uri.fromFile(target))
        // Journal before enqueue. Recovery locates the owned row if death precedes id commit.
        save(job)
        var id = 0L
        try {
            id = manager.enqueue(request)
            val active = job.copy(id = id)
            save(active)
            return snapshot(active)
        } catch (error: Exception) {
            if (id > 0) manager.remove(id)
            cancel(job)
            throw error
        }
    }

    fun requireJob(scope: String, key: String): Job {
        require(KEY.matches(key))
        return (read(scope) ?: error("Missing download")).also { require(it.key == key) }
    }

    fun snapshot(job: Job): Map<String, Any?> {
        val id = recoverId(job)
        if (id <= 0) return snapshot(job.key, "failed", 0, null)
        manager.query(DownloadManager.Query().setFilterById(id)).use { cursor ->
            if (!cursor.moveToFirst()) return snapshot(job.key, "failed", 0, null)
            fun long(column: String) = cursor.getLong(cursor.getColumnIndexOrThrow(column))
            val status = when (long(DownloadManager.COLUMN_STATUS).toInt()) {
                DownloadManager.STATUS_SUCCESSFUL -> "downloaded"
                DownloadManager.STATUS_PAUSED -> "paused"
                DownloadManager.STATUS_PENDING, DownloadManager.STATUS_RUNNING -> "downloading"
                else -> "failed"
            }
            return snapshot(job.key, status, long(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR).coerceAtLeast(0),
                long(DownloadManager.COLUMN_TOTAL_SIZE_BYTES).takeIf { it > 0 })
        }
    }

    fun completedFile(job: Job): File {
        if (snapshot(job)["status"] != "downloaded") throw FileNotFoundException("Completed download unavailable")
        return downloadFile(job).also {
            if (!it.isFile || it.length() <= 0) throw FileNotFoundException("Downloaded file unavailable")
        }
    }

    fun recordInstallEvidence(job: Job, sha256: String) {
        @Suppress("DEPRECATION")
        val installed = context.packageManager.getPackageInfo(context.packageName, 0)
        save(job.copy(installReceipt = UpdateInstallReceipt(installed.lastUpdateTime, sha256)))
    }

    fun cancel(job: Job) {
        val id = recoverId(job)
        if (id > 0) manager.remove(id)
        val downloaded = downloadFile(job)
        check(!downloaded.exists() || downloaded.delete())
        val staged = privateFile(job)
        check(!staged.exists() || staged.delete())
        val temporary = File(staged.parentFile, "${job.key}.part")
        check(!temporary.exists() || temporary.delete())
        check(preferences.edit().remove(job.scope).commit())
    }

    fun privateFile(job: Job): File = ownedFile(File(context.filesDir, "ota-installs"), job.key, "apk")

    private fun downloadFile(job: Job): File {
        val base = context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: error("Storage unavailable")
        return ownedFile(File(base, "flutter-ota"), job.key, "apk")
    }

    private fun ownedFile(directory: File, key: String, extension: String): File {
        require(KEY.matches(key))
        check(directory.isDirectory || directory.mkdirs())
        val file = File(directory, "$key.$extension").canonicalFile
        check(file.parentFile == directory.canonicalFile)
        return file
    }

    private fun read(scope: String): Job? {
        require(SCOPE.matches(scope))
        val json = preferences.getString(scope, null)?.let(::JSONObject) ?: return null
        val key = json.getString("job")
        require(KEY.matches(key))
        return Job(scope, key, json.getLong("id"), UpdateRelease.read(json.getJSONObject("release"), context.packageName),
            json.optBoolean("forceUpdate", false), json.optString("releaseNotes", ""),
            json.optJSONObject("installReceipt")?.let {
                UpdateInstallReceipt(it.getLong("previousUpdateTime"), it.getString("sha256"))
            })
    }

    private fun save(job: Job) {
        require(SCOPE.matches(job.scope))
        val json = JSONObject().put("job", job.key).put("id", job.id).put("release", job.release.json())
            .put("forceUpdate", job.forceUpdate).put("releaseNotes", job.releaseNotes)
        job.installReceipt?.let {
            json.put("installReceipt", JSONObject().put("previousUpdateTime", it.previousUpdateTime).put("sha256", it.sha256))
        }
        check(preferences.edit().putString(job.scope, json.toString()).commit())
    }

    private fun recoverId(job: Job): Long {
        if (job.id > 0) return job.id
        val target = Uri.fromFile(downloadFile(job)).toString()
        manager.query(DownloadManager.Query()).use { cursor ->
            while (cursor.moveToNext()) {
                if (cursor.getString(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI)) == target) {
                    val id = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_ID))
                    save(job.copy(id = id))
                    return id
                }
            }
        }
        return 0
    }

    private fun snapshot(key: String, status: String, received: Long, total: Long?) =
        mapOf("job" to key, "status" to status, "received" to received, "total" to total)

    companion object {
        val LOCK = Any()
        val SCOPE = Regex("[a-f0-9]{64}")
        val KEY = Regex("[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}")
    }
}
