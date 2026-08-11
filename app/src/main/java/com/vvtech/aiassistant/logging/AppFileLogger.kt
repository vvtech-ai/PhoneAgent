package com.vvtech.aiassistant.logging

import android.content.Context
import android.content.Intent
import android.util.Log as AndroidLog
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.BufferedWriter
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStreamWriter
import java.io.PrintWriter
import java.io.StringWriter
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

object AppFileLogger {

    private const val MAX_LOG_BYTES = 5L * 1024L * 1024L
    private const val RETAIN_DAYS = 15L
    private const val CRASH_FLUSH_TIMEOUT_SECONDS = 3L
    private const val LOG_PREFIX = "aiassistant"

    private val dateFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")
    private val fileTimeFormatter = DateTimeFormatter.ofPattern("yyyyMMdd_HHmmss")
    private val lineTimeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS")
    private val executor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "AppFileLogger").apply { isDaemon = true }
    }

    @Volatile
    private var appContext: Context? = null
    @Volatile
    private var logsDir: File? = null

    fun initialize(context: Context) {
        val applicationContext = context.applicationContext
        appContext = applicationContext
        logsDir = defaultLogsDir(applicationContext).also { it.mkdirs() }
        write("lifecycle", "logger", "file logger initialized dir=${logsDir?.absolutePath.orEmpty()}")
    }

    fun logConversation(
        direction: String,
        source: String,
        message: String,
        sessionId: String? = null,
        taskId: String? = null
    ) {
        write(
            category = "conversation",
            source = source,
            message = buildString {
                append("direction=").append(direction)
                sessionId?.takeIf { it.isNotBlank() }?.let { append(" sessionId=").append(it) }
                taskId?.takeIf { it.isNotBlank() }?.let { append(" taskId=").append(it) }
                append(" text=").append(message.sanitizeForLogLine())
            }
        )
    }

    fun write(category: String, source: String, message: String) {
        logInternal(
            priority = AndroidLog.INFO,
            category = category,
            source = source,
            message = message,
            throwable = null
        )
    }

    fun v(tag: String, message: String, throwable: Throwable? = null): Int {
        return logInternal(AndroidLog.VERBOSE, "verbose", tag, message, throwable)
    }

    fun d(tag: String, message: String, throwable: Throwable? = null): Int {
        return logInternal(AndroidLog.DEBUG, "debug", tag, message, throwable)
    }

    fun i(tag: String, message: String, throwable: Throwable? = null): Int {
        return logInternal(AndroidLog.INFO, "info", tag, message, throwable)
    }

    fun w(tag: String, message: String, throwable: Throwable? = null): Int {
        return logInternal(AndroidLog.WARN, "warn", tag, message, throwable)
    }

    fun e(tag: String, message: String, throwable: Throwable? = null): Int {
        return logInternal(AndroidLog.ERROR, "error", tag, message, throwable)
    }

    fun lifecycle(source: String, message: String): Int {
        return logInternal(AndroidLog.INFO, "lifecycle", source, message, null)
    }

    private fun logInternal(
        priority: Int,
        category: String,
        source: String,
        message: String,
        throwable: Throwable?
    ): Int {
        val logcatResult = writeToLogcat(priority, source, message, throwable)
        val fileMessage = if (throwable == null) {
            message
        } else {
            buildString {
                append(message)
                val throwableMessage = throwable.message
                if (!throwableMessage.isNullOrBlank()) {
                    append(" throwable=").append(throwableMessage)
                }
                append(" stack=").append(stackTraceToString(throwable))
            }
        }
        val line = formatLine(category, source, fileMessage)
        executor.execute {
            runCatching {
                val dir = ensureLogsDir()
                if (dir != null) {
                    deleteExpiredLogs(dir)
                    appendLine(dir, line)
                }
            }
        }
        return logcatResult
    }

    fun logCrashAndFlush(thread: Thread, throwable: Throwable) {
        val line = formatLine(
            category = "crash",
            source = thread.name.ifBlank { "unknown-thread" },
            message = stackTraceToString(throwable)
        )
        writeToLogcat(AndroidLog.ERROR, "crash", line, throwable)
        val latch = CountDownLatch(1)
        executor.execute {
            runCatching {
                val dir = ensureLogsDir()
                if (dir != null) {
                    appendLine(dir, line)
                }
            }
            latch.countDown()
        }
        runCatching { latch.await(CRASH_FLUSH_TIMEOUT_SECONDS, TimeUnit.SECONDS) }
    }

    fun flush(timeoutMillis: Long = 2_000L) {
        val latch = CountDownLatch(1)
        executor.execute { latch.countDown() }
        runCatching { latch.await(timeoutMillis, TimeUnit.MILLISECONDS) }
    }

    suspend fun exportLogs(context: Context): File = zipLogs(context)

    suspend fun exportLogs(context: Context, openSharePanel: Boolean): File {
        val zipFile = zipLogs(context)
        if (openSharePanel) {
            openSharePanel(context, zipFile)
        }
        return zipFile
    }

    suspend fun shareLogs(context: Context) {
        exportLogs(context, openSharePanel = true)
    }

    suspend fun clearLogs(context: Context) = withContext(Dispatchers.IO) {
        val latch = CountDownLatch(1)
        var failure: Throwable? = null
        executor.execute {
            runCatching {
                val dir = ensureLogsDir(context.applicationContext)
                    ?: throw IllegalStateException("日志目录不可用")
                dir.listFiles()
                    ?.forEach { file ->
                        if (!file.deleteRecursively() && file.exists()) {
                            throw IllegalStateException("删除日志文件失败: ${file.name}")
                        }
                    }
            }.onFailure { failure = it }
            latch.countDown()
        }
        if (!latch.await(CRASH_FLUSH_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
            throw IllegalStateException("清理日志目录超时")
        }
        failure?.let { throw IllegalStateException("清理日志目录失败", it) }
    }

    private suspend fun zipLogs(context: Context): File = withContext(Dispatchers.IO) {
        flush()
        val dir = ensureLogsDir(context.applicationContext)
            ?: throw IllegalStateException("日志目录不可用")
        val exportRoot = context.getExternalFilesDir(null) ?: context.filesDir
        val exportDir = File(exportRoot, "logs_exports").also { it.mkdirs() }
        val zipFile = File(exportDir, "aiassistant-logs-${LocalDateTime.now().format(fileTimeFormatter)}.zip")
        ZipOutputStream(FileOutputStream(zipFile)).use { zip ->
            dir.walkTopDown()
                .filter { it.isFile }
                .sortedBy { it.name }
                .forEach { file ->
                    zip.putNextEntry(ZipEntry(file.relativeTo(dir).invariantSeparatorsPath))
                    file.inputStream().use { input -> input.copyTo(zip) }
                    zip.closeEntry()
                }
        }
        zipFile
    }

    private fun openSharePanel(context: Context, zipFile: File) {
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.ota.fileprovider",
            zipFile
        )
        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = "application/zip"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val chooser = Intent.createChooser(shareIntent, "导出日志")
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(chooser)
    }

    private fun writeToLogcat(
        priority: Int,
        source: String,
        message: String,
        throwable: Throwable?
    ): Int {
        val tag = source.toLogcatTag()
        return runCatching {
            when (priority) {
                AndroidLog.VERBOSE -> if (throwable == null) AndroidLog.v(tag, message) else AndroidLog.v(tag, message, throwable)
                AndroidLog.DEBUG -> if (throwable == null) AndroidLog.d(tag, message) else AndroidLog.d(tag, message, throwable)
                AndroidLog.INFO -> if (throwable == null) AndroidLog.i(tag, message) else AndroidLog.i(tag, message, throwable)
                AndroidLog.WARN -> if (throwable == null) AndroidLog.w(tag, message) else AndroidLog.w(tag, message, throwable)
                AndroidLog.ERROR -> if (throwable == null) AndroidLog.e(tag, message) else AndroidLog.e(tag, message, throwable)
                else -> AndroidLog.println(priority, tag, message)
            }
        }.getOrDefault(0)
    }

    private fun defaultLogsDir(context: Context): File {
        val externalRoot = context.getExternalFilesDir(null) ?: context.filesDir
        return File(externalRoot, "logs")
    }

    private fun ensureLogsDir(context: Context? = appContext): File? {
        val existing = logsDir
        if (existing != null) {
            existing.mkdirs()
            return existing
        }
        val resolvedContext = context ?: return null
        return defaultLogsDir(resolvedContext).also {
            it.mkdirs()
            logsDir = it
        }
    }

    private fun appendLine(dir: File, line: String) {
        val target = resolveWritableLogFile(dir)
        BufferedWriter(OutputStreamWriter(FileOutputStream(target, true), Charsets.UTF_8)).use { writer ->
            writer.append(line)
            writer.newLine()
            writer.flush()
        }
    }

    private fun resolveWritableLogFile(dir: File): File {
        val date = LocalDate.now().format(dateFormatter)
        var index = 0
        while (true) {
            val suffix = if (index == 0) "" else ".$index"
            val file = File(dir, "$LOG_PREFIX-$date$suffix.log")
            if (!file.exists() || file.length() < MAX_LOG_BYTES) {
                return file
            }
            index += 1
        }
    }

    private fun deleteExpiredLogs(dir: File) {
        val cutoff = LocalDate.now().minusDays(RETAIN_DAYS - 1)
        dir.listFiles()
            ?.filter { it.isFile && it.name.startsWith("$LOG_PREFIX-") && it.name.endsWith(".log") }
            ?.forEach { file ->
                val dateText = file.name
                    .removePrefix("$LOG_PREFIX-")
                    .substringBefore(".log")
                    .substringBefore(".")
                val date = runCatching { LocalDate.parse(dateText, dateFormatter) }.getOrNull()
                if (date != null && date.isBefore(cutoff)) {
                    runCatching { file.delete() }
                }
            }
    }

    private fun formatLine(category: String, source: String, message: String): String {
        return buildString {
            append(LocalDateTime.now().format(lineTimeFormatter))
            append(" [").append(category.sanitizeForLogLine()).append("]")
            append(" [").append(source.sanitizeForLogLine()).append("] ")
            append(message.sanitizeForLogLine())
        }
    }

    private fun stackTraceToString(throwable: Throwable): String {
        val writer = StringWriter()
        throwable.printStackTrace(PrintWriter(writer))
        return writer.toString()
    }

    private fun String.sanitizeForLogLine(): String {
        return replace("\r", "\\r")
            .replace("\n", "\\n")
            .take(16_000)
    }

    private fun String.toLogcatTag(): String {
        return sanitizeForLogLine()
            .ifBlank { "AppFileLogger" }
            .take(23)
    }

}
