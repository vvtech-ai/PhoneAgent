package com.vvtech.aiassistant.logging

object AppCrashHandler {

    private var installed = false
    private var previousHandler: Thread.UncaughtExceptionHandler? = null

    fun install() {
        if (installed) return
        installed = true
        previousHandler = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            AppFileLogger.logCrashAndFlush(thread, throwable)
            previousHandler?.uncaughtException(thread, throwable)
                ?: throw throwable
        }
    }
}
