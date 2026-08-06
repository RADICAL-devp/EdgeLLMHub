package com.omoyari.greentech.doctor_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger

class MainActivity : FlutterActivity() {
    private var mlcHandler: MLCLLMHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mlcHandler = MLCLLMHandler(this, flutterEngine.dartExecutor.binaryMessenger)
    }
}
