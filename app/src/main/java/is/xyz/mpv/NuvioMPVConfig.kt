package `is`.xyz.mpv

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.util.Log

/**
 * NuvioTV Tuned mpv Configuration Engine
 * Optimized specifically for Android TV, 4K Remux / VOD, HDR10, Dolby Vision and Hi-Fi Audio Passthrough.
 */
object NuvioMPVConfig {
    private const val TAG = "NuvioMPVConfig"

    data class TvPlayerOptions(
        val hardwareDecoding: Boolean = true,
        val enableHdrSignaling: Boolean = true,
        val audioPassthrough: Boolean = true,
        val customCacheMegabytes: Int? = null,
        val subtitleStyling: Boolean = true,
        val forceSeekable: Boolean = true
    )

    /**
     * Applies full Android TV profile to MPVLib instance.
     */
    @JvmStatic
    fun applyTvProfile(context: Context, options: TvPlayerOptions = TvPlayerOptions()) {
        Log.i(TAG, "Applying NuvioTV MPV Profile with options: $options")

        // 1. Hardware Decoding (Zero-Copy to Surface)
        if (options.hardwareDecoding) {
            MPVLib.setOptionString("hwdec", "mediacodec")
            MPVLib.setOptionString("hwdec-codecs", "h264,hevc,vp9,av1,mpeg2video,mpeg4,vc1,prores")
        } else {
            MPVLib.setOptionString("hwdec", "no")
        }

        // 2. Video Output & HDR / Dolby Vision Color Signaling
        MPVLib.setOptionString("gpu-context", "android")
        MPVLib.setOptionString("opengl-es", "yes")
        
        if (options.enableHdrSignaling) {
            MPVLib.setOptionString("target-colorspace-hint", "yes")
            MPVLib.setOptionString("tone-mapping", "auto")
            MPVLib.setOptionString("target-trc", "auto")
            MPVLib.setOptionString("target-prim", "auto")
        }

        // 3. Audio Configuration & Bitstream Passthrough (Dolby Atmos / DTS-HD)
        MPVLib.setOptionString("ao", "audiotrack,opensles")
        MPVLib.setOptionString("audio-set-media-role", "yes")
        MPVLib.setOptionString("audio-pitch-correction", "yes")
        MPVLib.setOptionString("audio-channels", "auto-safe")

        if (options.audioPassthrough) {
            MPVLib.setOptionString("audio-spdif", "ac3,eac3,dts,truehd,dts-hd")
        } else {
            MPVLib.setOptionString("audio-spdif", "")
        }

        // 4. Subtitle Rendering (ASS/SSA Anime & Movie compatibility)
        if (options.subtitleStyling) {
            MPVLib.setOptionString("blend-subtitles", "yes")
            MPVLib.setOptionString("sub-ass-vsfilter-blur-compat", "yes")
            MPVLib.setOptionString("sub-ass-override", "no")
            MPVLib.setOptionString("sub-auto", "fuzzy")
        }

        // 5. 4K High-Bitrate Demuxer Cache & Buffer Allocation
        val cacheMb = options.customCacheMegabytes ?: resolveOptimalCacheMb(context)
        val cacheBytes = cacheMb.toLong() * 1024L * 1024L

        MPVLib.setOptionString("cache", "yes")
        MPVLib.setOptionString("demuxer-max-bytes", "$cacheBytes")
        MPVLib.setOptionString("demuxer-max-back-bytes", "${cacheBytes / 3}")
        MPVLib.setOptionString("demuxer-readahead-secs", "30")

        if (options.forceSeekable) {
            MPVLib.setOptionString("force-seekable", "yes")
        }

        // 6. Network & TLS
        MPVLib.setOptionString("tls-verify", "yes")
        MPVLib.setOptionString("video-sync", "audio")
    }

    /**
     * Resolves the optimal cache size based on available RAM.
     */
    @JvmStatic
    fun resolveOptimalCacheMb(context: Context): Int {
        return try {
            val actManager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            val memoryClass = actManager?.memoryClass ?: 128
            when {
                memoryClass >= 384 -> 200 // High-end Box / TV (3GB-4GB+ RAM)
                memoryClass >= 192 -> 128 // Standard TV (2GB RAM)
                else -> 64 // Budget Stick (1GB RAM)
            }
        } catch (_: Exception) {
            96
        }
    }
}
