package com.chronos.drift.app

import android.content.Context
import android.os.Build
import android.os.SystemClock
import androidx.annotation.Keep
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

@Keep
class ClockSync(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.chronos.drift/clock_sync"
    }

    /**
     * Data class representing a snapshot of the various system clocks.
     * This allows the Rust core to compare Android hardware-level 
     * timestamps with NTP-derived atomic time.
     */
    data class ClockSnapshot(
        val uptimeMillis: Long,
        val elapsedRealtimeNanos: Long,
        val wallClockMillis: Long,
        val threadCpuTimeNanos: Long
    ) {
        fun toMap(): Map<String, Any> {
            return mapOf(
                "uptimeMillis" to uptimeMillis,
                "elapsedRealtimeNanos" to elapsedRealtimeNanos,
                "wallClockMillis" to wallClockMillis,
                "threadCpuTimeNanos" to threadCpuTimeNanos
            )
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getHardwareTimestamps" -> {
                val snapshot = getHardwareTimestamps()
                result.success(snapshot.toMap())
            }
            "getClockPrecision" -> {
                result.success(getClockPrecision())
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    /**
     * Captures multiple hardware clock facets simultaneously.
     * - elapsedRealtimeNanos: Time since boot, including sleep. Best for interval timing.
     * - uptimeMillis: Time since boot, excluding sleep.
     * - wallClockMillis: User-adjustable system time.
     * - threadCpuTimeNanos: Native CPU cycles consumed by the calling thread.
     */
    private fun getHardwareTimestamps(): ClockSnapshot {
        return ClockSnapshot(
            uptimeMillis = SystemClock.uptimeMillis(),
            elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos(),
            wallClockMillis = System.currentTimeMillis(),
            threadCpuTimeNanos = SystemClock.currentThreadTimeMillis() * 1_000_000L
        )
    }

    /**
     * Estimates the resolution/precision of the system's monotonic clock in nanoseconds.
     */
    private fun getClockPrecision(): Long {
        val iterations = 100
        var minDiff = Long.MAX_VALUE
        
        for (i in 0 until iterations) {
            val t1 = SystemClock.elapsedRealtimeNanos()
            var t2 = SystemClock.elapsedRealtimeNanos()
            
            // Wait for a tick
            while (t1 == t2) {
                t2 = SystemClock.elapsedRealtimeNanos()
            }
            
            val diff = t2 - t1
            if (diff < minDiff) {
                minDiff = diff
            }
        }
        return minDiff
    }

    /**
     * Utility to calculate drift since a specific boot-relative reference.
     */
    fun calculateLocalDrift(referenceNanos: Long): Long {
        val current = SystemClock.elapsedRealtimeNanos()
        return current - referenceNanos
    }
}