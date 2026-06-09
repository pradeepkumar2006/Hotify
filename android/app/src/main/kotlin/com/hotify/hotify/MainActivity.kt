package com.hotify.hotify

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceFragmentActivity

class MainActivity : AudioServiceFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Request the highest refresh rate the display supports (90Hz, 120Hz, etc.)
        enableHighRefreshRate()

        // Keep screen on while the music app is in the foreground
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    private fun enableHighRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+ (API 30): Use the modern setFrameRate API via display modes
            val display = display ?: return
            val supportedModes = display.supportedModes

            // Pick the mode with the highest refresh rate
            val highestRateMode = supportedModes.maxByOrNull { it.refreshRate }

            if (highestRateMode != null) {
                val params = window.attributes
                params.preferredDisplayModeId = highestRateMode.modeId
                window.attributes = params
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            // Android 6-10 (API 23-29): Use preferredDisplayModeId on WindowManager
            val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
            val display = windowManager.defaultDisplay
            val supportedModes = display.supportedModes

            val highestRateMode = supportedModes.maxByOrNull { it.refreshRate }
            if (highestRateMode != null) {
                val params = window.attributes
                params.preferredDisplayModeId = highestRateMode.modeId
                window.attributes = params
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Re-apply high refresh rate when returning to the app
        enableHighRefreshRate()
    }
}
