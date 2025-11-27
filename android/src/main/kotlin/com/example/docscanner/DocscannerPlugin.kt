package com.example.docscanner

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.util.Log
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import com.google.android.gms.mlkit.documentscanner.GmsDocumentScanner
import com.google.android.gms.mlkit.documentscanner.GmsDocumentScannerOptions
import com.google.android.gms.mlkit.documentscanner.GmsDocumentScannerOptions.RESULT_FORMAT_JPEG
import com.google.android.gms.mlkit.documentscanner.GmsDocumentScannerOptions.RESULT_FORMAT_PDF
import com.google.android.gms.mlkit.documentscanner.GmsDocumentScannerOptions.SCANNER_MODE_FULL
import com.google.android.gms.mlkit.documentscanner.GmsDocumentScanning
import com.google.android.gms.mlkit.documentscanner.GmsDocumentScanningResult
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.io.FileOutputStream

/**
 * Flutter plugin for document scanning using ML Kit Document Scanner API.
 */
class DocscannerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    PluginRegistry.ActivityResultListener {

    companion object {
        private const val TAG = "DocscannerPlugin"
        private const val CHANNEL = "docscanner"
        private const val SCAN_REQUEST_CODE = 9001
    }

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingResult: Result? = null
    private var performOcr: Boolean = false
    private var scanner: GmsDocumentScanner? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "scanDocument" -> {
                val allowMultiplePages = call.argument<Boolean>("allowMultiplePages") ?: true
                val outputFormat = call.argument<String>("outputFormat") ?: "jpeg"
                performOcr = false
                startDocumentScanner(result, allowMultiplePages, outputFormat)
            }
            "scanReceipt" -> {
                val language = call.argument<String>("language") ?: "hr"
                performOcr = call.argument<Boolean>("performOcr") ?: true
                startDocumentScanner(result, allowMultiplePages = true, outputFormat = "jpeg")
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun startDocumentScanner(result: Result, allowMultiplePages: Boolean, outputFormat: String) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Activity is not available", null)
            return
        }

        if (pendingResult != null) {
            result.error("ALREADY_SCANNING", "A scan is already in progress", null)
            return
        }

        pendingResult = result

        // Configure scanner options
        val optionsBuilder = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(true)
            .setPageLimit(if (allowMultiplePages) 100 else 1)
            .setScannerMode(SCANNER_MODE_FULL)

        // Set result formats
        when (outputFormat.lowercase()) {
            "pdf" -> optionsBuilder.setResultFormats(RESULT_FORMAT_PDF)
            "both" -> optionsBuilder.setResultFormats(RESULT_FORMAT_JPEG, RESULT_FORMAT_PDF)
            else -> optionsBuilder.setResultFormats(RESULT_FORMAT_JPEG)
        }

        val options = optionsBuilder.build()
        scanner = GmsDocumentScanning.getClient(options)

        scanner?.getStartScanIntent(currentActivity)
            ?.addOnSuccessListener { intentSender ->
                try {
                    currentActivity.startIntentSenderForResult(
                        intentSender,
                        SCAN_REQUEST_CODE,
                        null,
                        0,
                        0,
                        0,
                        null
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start scanner", e)
                    pendingResult?.error("SCANNER_ERROR", "Failed to start scanner: ${e.message}", null)
                    pendingResult = null
                }
            }
            ?.addOnFailureListener { e ->
                Log.e(TAG, "Failed to get scanner intent", e)
                pendingResult?.error("SCANNER_ERROR", "Failed to initialize scanner: ${e.message}", null)
                pendingResult = null
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != SCAN_REQUEST_CODE) {
            return false
        }

        val result = pendingResult
        if (result == null) {
            Log.w(TAG, "No pending result for scan")
            return true
        }

        if (resultCode == Activity.RESULT_CANCELED) {
            result.success(null) // User cancelled
            pendingResult = null
            return true
        }

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.error("SCAN_FAILED", "Scan failed or was cancelled", null)
            pendingResult = null
            return true
        }

        // Get scanning result
        val scanningResult = GmsDocumentScanningResult.fromActivityResultIntent(data)
        if (scanningResult == null) {
            result.error("NO_RESULT", "No scanning result received", null)
            pendingResult = null
            return true
        }

        processScanResult(scanningResult, result)
        return true
    }

    private fun processScanResult(scanningResult: GmsDocumentScanningResult, result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Activity is not available", null)
            pendingResult = null
            return
        }

        val imagePaths = mutableListOf<String>()
        var pdfPath: String? = null

        // Process pages
        val pages = scanningResult.pages
        if (pages != null) {
            for (page in pages) {
                val imageUri = page.imageUri
                val savedPath = saveImageToCache(currentActivity, imageUri)
                if (savedPath != null) {
                    imagePaths.add(savedPath)
                }
            }
        }

        // Get PDF if available
        val pdf = scanningResult.pdf
        if (pdf != null) {
            val pdfUri = pdf.uri
            val savedPdfPath = savePdfToCache(currentActivity, pdfUri)
            if (savedPdfPath != null) {
                pdfPath = savedPdfPath
            }
        }

        // Perform OCR if requested
        if (performOcr && imagePaths.isNotEmpty()) {
            performOcrOnImages(imagePaths, result) { ocrText ->
                val resultMap = mapOf(
                    "success" to true,
                    "imagePaths" to imagePaths,
                    "pdfPath" to pdfPath,
                    "pageCount" to imagePaths.size,
                    "ocrText" to ocrText
                )
                result.success(resultMap)
                pendingResult = null
            }
        } else {
            val resultMap = mapOf(
                "success" to true,
                "imagePaths" to imagePaths,
                "pdfPath" to pdfPath,
                "pageCount" to imagePaths.size
            )
            result.success(resultMap)
            pendingResult = null
        }
    }

    private fun saveImageToCache(activity: Activity, uri: Uri): String? {
        return try {
            val inputStream = activity.contentResolver.openInputStream(uri)
            val cacheDir = File(activity.cacheDir, "docscanner")
            if (!cacheDir.exists()) {
                cacheDir.mkdirs()
            }
            val file = File(cacheDir, "scan_${System.currentTimeMillis()}.jpg")
            val outputStream = FileOutputStream(file)
            inputStream?.copyTo(outputStream)
            inputStream?.close()
            outputStream.close()
            file.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save image", e)
            null
        }
    }

    private fun savePdfToCache(activity: Activity, uri: Uri): String? {
        return try {
            val inputStream = activity.contentResolver.openInputStream(uri)
            val cacheDir = File(activity.cacheDir, "docscanner")
            if (!cacheDir.exists()) {
                cacheDir.mkdirs()
            }
            val file = File(cacheDir, "scan_${System.currentTimeMillis()}.pdf")
            val outputStream = FileOutputStream(file)
            inputStream?.copyTo(outputStream)
            inputStream?.close()
            outputStream.close()
            file.absolutePath
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save PDF", e)
            null
        }
    }

    private fun performOcrOnImages(imagePaths: List<String>, result: Result, callback: (String) -> Unit) {
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        // Use synchronized list to prevent race conditions with concurrent callbacks
        val textResults = java.util.Collections.synchronizedList(mutableListOf<String>())
        // Initialize with empty strings for each position to maintain order
        for (i in imagePaths.indices) {
            textResults.add("")
        }
        var processedCount = java.util.concurrent.atomic.AtomicInteger(0)

        val currentActivity = activity
        if (currentActivity == null) {
            callback("")
            return
        }

        for ((index, imagePath) in imagePaths.withIndex()) {
            try {
                val file = File(imagePath)
                val inputImage = InputImage.fromFilePath(currentActivity, Uri.fromFile(file))

                recognizer.process(inputImage)
                    .addOnSuccessListener { visionText ->
                        textResults[index] = visionText.text
                        if (processedCount.incrementAndGet() == imagePaths.size) {
                            callback(textResults.joinToString("\n\n---PAGE BREAK---\n\n"))
                        }
                    }
                    .addOnFailureListener { e ->
                        Log.e(TAG, "OCR failed for $imagePath", e)
                        textResults[index] = ""
                        if (processedCount.incrementAndGet() == imagePaths.size) {
                            callback(textResults.joinToString("\n\n---PAGE BREAK---\n\n"))
                        }
                    }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to process image for OCR", e)
                if (processedCount.incrementAndGet() == imagePaths.size) {
                    callback(textResults.joinToString("\n\n---PAGE BREAK---\n\n"))
                }
            }
        }

        if (imagePaths.isEmpty()) {
            callback("")
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeActivityResultListener(this)
        activity = null
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activity = null
        activityBinding = null
    }
}
