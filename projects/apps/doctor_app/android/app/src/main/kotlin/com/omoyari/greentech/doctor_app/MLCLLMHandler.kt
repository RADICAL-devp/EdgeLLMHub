package com.omoyari.greentech.doctor_app

import android.content.Context
import android.util.Base64
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.Registrar
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.mlc.llm.MLCEngine
import org.mlc.llm.ChatCompletionMessage
import org.mlc.llm.ChatCompletionChunk
import org.mlc.llm.ContentDelta
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest

/**
 * Android native LLM handler using MLC Android runtime.
 * Mirrors iOS MLCLLMHandler functionality.
 */
class MLCLLMHandler(
    private val context: Context,
    private val messenger: io.flutter.plugin.common.BinaryMessenger
) : MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "com.example.clinical/llm"
        const val STREAM_CHANNEL = "com.example.clinical/llm_stream"
        const val DONE_SENTINEL = "[DONE]"
        const val MODEL_BUNDLE_NAME = "SmolLM-350M-Instruct-q4f16_1-MLC"
        const val MODEL_LIB = "SmolLM-350M-Instruct-q4f16_1-MLC"
        const val MAX_CONTEXT_TOKENS = 2048
        private const val TAG = "MLCLLMHandler"
    }

    private val methodChannel: MethodChannel
    private val streamChannel: EventChannel
    private var engine: MLCEngine? = null
    private var eventSink: EventChannel.EventSink? = null
    private var isEngineReady = false
    private var generationJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.IO)

    init {
        methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
        streamChannel = EventChannel(messenger, STREAM_CHANNEL)

        methodChannel.setMethodCallHandler(this)
        streamChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isAvailable" -> result.success(isEngineReady)

            "getModelInfo" -> result.success(modelInfo())

            "initialize" -> {
                scope.launch {
                    try {
                        initializeEngine()
                        result.success(null)
                    } catch (e: Exception) {
                        Log.e(TAG, "Initialize failed", e)
                        result.error("INIT_FAILED", e.message, null)
                    }
                }
            }

            "generate" -> {
                val prompt = extractPrompt(call, result) ?: return
                scope.launch {
                    try {
                        val response = generateNonStreaming(prompt)
                        result.success(response)
                    } catch (e: Exception) {
                        Log.e(TAG, "Generate failed", e)
                        result.error("GENERATION_FAILED", e.message, null)
                    }
                }
            }

            "generateStream" -> {
                val prompt = extractPrompt(call, result) ?: return
                generationJob?.cancel()
                generationJob = scope.launch {
                    try {
                        generateStreaming(prompt)
                    } catch (e: Exception) {
                        Log.e(TAG, "Stream failed", e)
                        eventSink?.error("GENERATION_FAILED", e.message, null)
                    }
                }
                result.success(null)
            }

            "warmUp" -> {
                scope.launch {
                    try {
                        _ = generateNonStreaming("Hello")
                        result.success("OK")
                    } catch (e: Exception) {
                        Log.e(TAG, "Warm-up failed", e)
                        result.error("WARMUP_FAILED", e.message, null)
                    }
                }
            }

            "cancel" -> {
                generationJob?.cancel()
                generationJob = null
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private fun extractPrompt(call: MethodCall, result: Result): String? {
        val args = call.arguments as? Map<String, Any>
        val prompt = args?.get("prompt") as? String
        if (prompt == null || prompt.trim().isEmpty()) {
            result.error("INVALID_ARGS", "Missing non-empty 'prompt' argument", null)
            return null
        }
        return prompt
    }

    private fun initializeEngine() {
        if (isEngineReady) return

        val modelDir = File(context.filesDir, MODEL_BUNDLE_NAME)
        if (!modelDir.exists()) {
            // Try assets first
            copyModelFromAssets(modelDir)
        }

        if (!modelDir.exists()) {
            throw IllegalStateException(
                "SmolLM-350M not found. Copy model to assets/$MODEL_BUNDLE_NAME/ or run prepare_model.sh"
            )
        }

        engine = MLCEngine()
        engine?.reload(modelDir.absolutePath, MODEL_LIB)
        isEngineReady = true
        Log.i(TAG, "MLC engine initialized at ${modelDir.absolutePath}")
    }

    private fun copyModelFromAssets(destDir: File) {
        try {
            val assetManager = context.assets
            val files = assetManager.list(MODEL_BUNDLE_NAME) ?: return
            if (!destDir.exists()) destDir.mkdirs()

            for (file in files) {
                val input = assetManager.open("$MODEL_BUNDLE_NAME/$file")
                val output = File(destDir, file)
                output.copyFrom(input)
                input.close()
            }
            Log.i(TAG, "Model copied from assets to ${destDir.absolutePath}")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to copy model from assets", e)
        }
    }

    private fun generateNonStreaming(prompt: String): String {
        val buffer = StringBuilder()
        val messages = listOf(ChatCompletionMessage(role = "user", content = prompt))

        val stream = engine?.chat?.completions?.create(messages = messages)
        if (stream == null) throw IllegalStateException("Engine not initialized")

        for (chunk in stream) {
            if (generationJob?.isCancelled == true) {
                throw InterruptedException("Generation cancelled")
            }
            val token = chunk.choices.firstOrNull()?.delta?.content?.text
            if (token != null && token.isNotEmpty()) {
                buffer.append(token)
            }
        }
        return buffer.toString()
    }

    private fun generateStreaming(prompt: String) {
        if (eventSink == null) throw IllegalStateException("No event sink")

        val messages = listOf(ChatCompletionMessage(role = "user", content = prompt))
        val stream = engine?.chat?.completions?.create(messages = messages)
        if (stream == null) throw IllegalStateException("Engine not initialized")

        for (chunk in stream) {
            if (generationJob?.isCancelled == true) {
                throw InterruptedException("Generation cancelled")
            }
            val token = chunk.choices.firstOrNull()?.delta?.content?.text
            if (token != null && token.isNotEmpty()) {
                eventSink?.success(token)
            }
        }
        eventSink?.success(DONE_SENTINEL)
    }

    private fun modelInfo(): Map<String, Any> {
        val modelDir = File(context.filesDir, MODEL_BUNDLE_NAME)
        val checksum = computeChecksum(modelDir)
        return mapOf(
            "modelId" to MODEL_BUNDLE_NAME,
            "modelLib" to MODEL_LIB,
            "modelPath" to modelDir.absolutePath,
            "bundled" to modelDir.exists(),
            "ready" to isEngineReady,
            "contextWindowTokens" to MAX_CONTEXT_TOKENS,
            "checksumSha256" to checksum ?: "",
            "runtime" to "MLCAndroid"
        )
    }

    private fun computeChecksum(dir: File): String? {
        if (!dir.exists()) return null
        try {
            val digest = MessageDigest.getInstance("SHA-256")
            dir.walkTopDown()
                .filter { it.isFile }
                .sortedBy { it.name }
                .forEach { file ->
                    FileInputStream(file).use { input ->
                        val buffer = ByteArray(8192)
                        var len = input.read(buffer)
                        while (len > 0) {
                            digest.update(buffer, 0, len)
                            len = input.read(buffer)
                        }
                    }
                }
            return Base64.encodeToString(digest.digest(), Base64.NO_WRAP)
        } catch (e: Exception) {
            Log.w(TAG, "Checksum failed", e)
            return null
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink): Any? {
        eventSink = events
        return null
    }

    override fun onCancel(arguments: Any?): Any? {
        generationJob?.cancel()
        generationJob = null
        eventSink = null
        return null
    }
}
