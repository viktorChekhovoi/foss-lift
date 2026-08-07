package com.fosslift.foss_lift

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The activity, plus the one thing this app asks Android for directly: the
 * vibrator.
 *
 * There is no plugin for it because what the rest timer needs is not what a
 * plugin offers. `HapticFeedback` — the Flutter-side API this replaced — goes
 * through `View.performHapticFeedback`, so the phone's touch-feedback switch
 * turns it off, and its strongest constant is a tick. A rest ending has to be
 * felt through a gym bag, so it is a waveform at full amplitude played with
 * alarm usage, which is what carries it past a silenced ringer.
 *
 * See lib/services/rest_buzz.dart for the caller and the pattern.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BUZZ_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "buzz" -> {
                        val pattern = call.argument<List<Int>>("pattern")
                        if (pattern == null || pattern.isEmpty()) {
                            result.error("bad_pattern", "no waveform to play", null)
                        } else {
                            buzz(pattern.map { it.toLong() }.toLongArray())
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Plays [timings] once — alternating wait and buzz, as the Dart side sends it. */
    private fun buzz(timings: LongArray) {
        val vibrator = vibrator() ?: return
        if (!vibrator.hasVibrator()) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Full amplitude on the buzzing segments rather than DEFAULT_AMPLITUDE,
            // which on a good few phones is the gentle one used for keystrokes.
            // Phones with no amplitude control ignore the array and buzz flat out,
            // which is the same answer.
            val amplitudes = IntArray(timings.size) { i ->
                if (i % 2 == 1) MAX_AMPLITUDE else 0
            }
            val effect = VibrationEffect.createWaveform(timings, amplitudes, NO_REPEAT)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                vibrator.vibrate(
                    effect,
                    VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM),
                )
            } else {
                vibrator.vibrate(effect, alarmAudioAttributes())
            }
        } else {
            @Suppress("DEPRECATION")
            vibrator.vibrate(timings, NO_REPEAT, alarmAudioAttributes())
        }
    }

    private fun vibrator(): Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager =
                getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager?
            manager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator?
        }

    /**
     * Alarm usage, which is what lets the buzz through a phone on silent. It is
     * still refused by a Do-Not-Disturb that silences alarms, and that refusal is
     * the user's to make.
     */
    private fun alarmAudioAttributes(): AudioAttributes =
        AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

    private companion object {
        /** Matches lib/services/rest_buzz.dart. */
        const val BUZZ_CHANNEL = "com.fosslift.foss_lift/buzz"

        /** No index to loop back to: the waveform plays once and stops. */
        const val NO_REPEAT = -1

        /**
         * Full strength. Written out rather than taken from
         * `VibrationEffect.MAX_AMPLITUDE`, which is hidden API — the scale is
         * documented as 1–255 and this is the top of it.
         */
        const val MAX_AMPLITUDE = 255
    }
}
