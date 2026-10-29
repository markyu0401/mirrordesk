package io.github.markyu0401.mirrordesk

import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.projection.MediaProjection
import android.view.Surface

class Encoder(private val projection: MediaProjection) {
    private var codec: MediaCodec? = null
    private var surface: Surface? = null
    private var virtualDisplay: VirtualDisplay? = null

    fun start() {
        val format = MediaFormat.createVideoFormat("video/avc", 1080, 2400).apply {
            setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
            setInteger(MediaFormat.KEY_BIT_RATE, 16_000_000)
            setInteger(MediaFormat.KEY_FRAME_RATE, 60)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
        }
        val c = MediaCodec.createEncoderByType("video/avc")
        c.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        surface = c.createInputSurface()
        c.start()
        codec = c
        virtualDisplay = projection.createVirtualDisplay(
            "MirrorDesk",
            1080, 2400, 320,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            surface, null, null
        )
    }

    fun stop() {
        virtualDisplay?.release()
        virtualDisplay = null
        codec?.stop()
        codec?.release()
        codec = null
        surface?.release()
        surface = null
    }
}
