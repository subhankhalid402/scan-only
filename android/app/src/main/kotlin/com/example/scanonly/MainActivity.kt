package com.example.scanonly

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val channel = "scanonly/openwith"
    private var pendingSharedPath: String? = null
    private var pendingSharedPaths: List<String>? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        when (intent.action) {
            Intent.ACTION_VIEW, Intent.ACTION_EDIT -> {
                val uri = intent.data
                if (uri != null) {
                    pendingSharedPath = copyUriToCache(uri)
                }
            }
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                val uri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
                if (uri != null) {
                    pendingSharedPath = copyUriToCache(uri)
                } else {
                    pendingSharedPath = intent.dataString
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                @Suppress("DEPRECATION")
                val uris: ArrayList<Uri>? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
                }
                if (uris != null) {
                    pendingSharedPaths = uris.mapNotNull { copyUriToCache(it) }
                    if (pendingSharedPaths?.size == 1) {
                        pendingSharedPath = pendingSharedPaths?.first()
                        pendingSharedPaths = null
                    }
                }
            }
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val fileName = getFileNameFromUri(uri) ?: "shared_file_${System.currentTimeMillis()}"
            val cacheFile = File(cacheDir, fileName)
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(cacheFile).use { output ->
                    input.copyTo(output)
                }
            }
            cacheFile.absolutePath
        } catch (e: Exception) {
            uri.toString()
        }
    }

    private fun getFileNameFromUri(uri: Uri): String? {
        if (uri.scheme == "content") {
            try {
                contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameIndex >= 0) {
                            return cursor.getString(nameIndex)
                        }
                    }
                }
            } catch (e: Exception) {
                // ignore
            }
        }
        return uri.lastPathSegment?.let {
            if (it.contains(".")) it else null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedFile" -> {
                        result.success(pendingSharedPath)
                        pendingSharedPath = null
                    }
                    "getInitialSharedFiles" -> {
                        result.success(pendingSharedPaths)
                        pendingSharedPaths = null
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
