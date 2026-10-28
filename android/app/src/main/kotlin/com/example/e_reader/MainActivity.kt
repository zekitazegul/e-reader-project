package com.example.e_reader

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.database.ContentObserver
import android.database.Cursor
import android.os.Handler
import android.os.Looper
import android.os.Environment
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private lateinit var folderChannel: MethodChannel
    private var pickerReply: MethodChannel.Result? = null
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var readerFullscreen = false
    private val restoreBars = Runnable {
        if (window.decorView.hasWindowFocus()) hideNavigation()
    }
    private val preferences by lazy { getSharedPreferences("book-folder", MODE_PRIVATE) }
    private var observer: ContentObserver? = null
    private var observedCursor: Cursor? = null
    private val extensions = setOf("epub", "pdf", "docx", "mobi", "prc", "azw", "azw3", "azw4", "kfx", "kpf")
    private fun selected(): Uri? = preferences.getString("tree", null)?.let(Uri::parse)
    private fun suggestedFolder(): Uri? {
        val root = Environment.getExternalStorageDirectory()
        for (parent in listOf(root, java.io.File(root, "Documents"), java.io.File(root, "Download"))) {
            for (name in listOf("Kitaplar", "kitaplar", "Books", "books")) {
                val folder = java.io.File(parent, name)
                if (folder.isDirectory) {
                    val relative = folder.relativeTo(root).path.replace(java.io.File.separatorChar, '/')
                    return DocumentsContract.buildDocumentUri("com.android.externalstorage.documents", "primary:$relative")
                }
            }
        }
        return null
    }

    private fun hideNavigation() {
        if (android.os.Build.VERSION.SDK_INT >= 30) {
            window.insetsController?.let {
                it.systemBarsBehavior = android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                it.hide(android.view.WindowInsets.Type.navigationBars())
                if (readerFullscreen) it.hide(android.view.WindowInsets.Type.statusBars())
                else it.show(android.view.WindowInsets.Type.statusBars())
            }
        } else {
            @Suppress("DEPRECATION")
            var flags = window.decorView.systemUiVisibility or android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
            @Suppress("DEPRECATION")
            flags = if (readerFullscreen) flags or android.view.View.SYSTEM_UI_FLAG_FULLSCREEN
                else flags and android.view.View.SYSTEM_UI_FLAG_FULLSCREEN.inv()
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = flags
        }
    }

    private fun scheduleNavigationRestore() {
        main.removeCallbacks(restoreBars)
        // Android temporarily prevents changing bar visibility after the IME
        // closes. Let that interval pass; edge-swipe bars remain transient.
        main.postDelayed(restoreBars, 1400)
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        if (android.os.Build.VERSION.SDK_INT >= 30) {
            window.decorView.setOnApplyWindowInsetsListener { view, insets ->
                if (insets.isVisible(android.view.WindowInsets.Type.navigationBars()) &&
                    !insets.isVisible(android.view.WindowInsets.Type.ime())) {
                    scheduleNavigationRestore()
                }
                view.onApplyWindowInsets(insets)
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.setOnSystemUiVisibilityChangeListener { visibility ->
                @Suppress("DEPRECATION")
                if (visibility and android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION == 0) {
                    scheduleNavigationRestore()
                }
            }
        }
        window.decorView.post { hideNavigation() }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) { hideNavigation(); scheduleNavigationRestore() }
        else main.removeCallbacks(restoreBars)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "e_reader/chrome").setMethodCallHandler { call, reply ->
            when (call.method) {
                "appVersion" -> {
                    val info = packageManager.getPackageInfo(packageName, 0)
                    val code = if (android.os.Build.VERSION.SDK_INT >= 28) info.longVersionCode else {
                        @Suppress("DEPRECATION")
                        info.versionCode.toLong()
                    }
                    reply.success(mapOf("version" to info.versionName, "build" to code))
                }
                "downloadUpdate" -> {
                    try {
                        val uri = Uri.parse(call.argument<String>("url") ?: "")
                        require(uri.scheme == "https" && uri.host == "github.com" &&
                            uri.path?.startsWith("/zekitazegul/e-reader-project/releases/download/") == true &&
                            uri.path?.endsWith(".apk") == true) { "Invalid update URL" }
                        val version = (call.argument<String>("version") ?: "latest").replace(Regex("[^A-Za-z0-9.+_-]"), "")
                        val request = android.app.DownloadManager.Request(uri)
                            .setTitle("E-Reader $version")
                            .setDescription("E-Reader")
                            .setMimeType("application/vnd.android.package-archive")
                            .setNotificationVisibility(android.app.DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                        val filename = "E-Reader-$version-${System.currentTimeMillis()}.apk"
                        if (android.os.Build.VERSION.SDK_INT >= 29) {
                            request.setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, filename)
                        } else {
                            request.setDestinationInExternalFilesDir(this, Environment.DIRECTORY_DOWNLOADS, filename)
                        }
                        val downloads = getSystemService(DOWNLOAD_SERVICE) as android.app.DownloadManager
                        downloads.enqueue(request)
                        reply.success(null)
                    } catch (e: Exception) { reply.error("update", e.message, null) }
                }
                "hideNavigation" -> { hideNavigation(); reply.success(null) }
                "setReaderFullscreen" -> {
                    readerFullscreen = call.arguments as? Boolean ?: false
                    hideNavigation()
                    scheduleNavigationRestore()
                    reply.success(null)
                }
                "openShortcut" -> {
                    if (call.argument<String>("key") == "share") {
                        worker.execute {
                            try {
                                val directory = java.io.File(cacheDir, "shared-apk").apply { mkdirs() }
                                val apk = java.io.File(directory, "E-Reader.apk")
                                java.io.File(applicationInfo.sourceDir).copyTo(apk, overwrite = true)
                                val uri = androidx.core.content.FileProvider.getUriForFile(this, "$packageName.apkshare", apk)
                                main.post {
                                    try {
                                        startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                                            type = "application/vnd.android.package-archive"
                                            putExtra(Intent.EXTRA_STREAM, uri)
                                            clipData = android.content.ClipData.newRawUri("E-Reader", uri)
                                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                        }, "E-Reader"))
                                        reply.success(null)
                                    } catch (e: Exception) { reply.error("share", e.message, null) }
                                }
                            } catch (e: Exception) { main.post { reply.error("share", e.message, null) } }
                        }
                        return@setMethodCallHandler
                    }
                    val language = call.argument<String>("language").let { if (it in listOf("tr", "en", "nl")) it else "en" }
                    val url = when (call.argument<String>("key")) {
                        "support" -> "https://zekitazegul.github.io/support/?lang=$language"
                        "kuran" -> "https://github.com/zekitazegul/kuran_app/releases/latest/download/Kuran-Installer.apk"
                        "cevsen" -> "https://github.com/zekitazegul/cevsen_app/releases/latest/download/Cevsen-Installer.apk"
                        else -> null
                    }
                    try {
                        if (url == null) reply.error("link", "Unknown shortcut", null)
                        else { startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))); reply.success(null) }
                    } catch (e: Exception) { reply.error("link", e.message, null) }
                }
                else -> reply.notImplemented()
            }
        }
        folderChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "e_reader/folder")
        folderChannel.setMethodCallHandler { call, reply ->
            when (call.method) {
                "discover" -> {
                    val offer = selected() == null && !preferences.getBoolean("discoveryOffered", false) && suggestedFolder() != null
                    if (offer) preferences.edit().putBoolean("discoveryOffered", true).apply()
                    reply.success(offer)
                }
                "pick" -> {
                    if (pickerReply != null) { reply.error("busy", null, null); return@setMethodCallHandler }
                    pickerReply = reply
                    try {
                        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                            (selected() ?: suggestedFolder())?.let { putExtra(DocumentsContract.EXTRA_INITIAL_URI, it) }
                        }, 9101)
                    } catch (e: Exception) { pickerReply = null; reply.error("folder", e.message, null) }
                }
                "location" -> reply.success(preferences.getString("name", null))
                "scan" -> worker.execute {
                    try {
                        val tree = selected()
                        if (tree == null) { main.post { reply.success(null) }; return@execute }
                        val result = mutableListOf<Map<String, Any>>()
                        val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
                        val columns = arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                            DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_SIZE,
                            DocumentsContract.Document.COLUMN_MIME_TYPE)
                        val cursor = contentResolver.query(children, columns, null, null, null)
                            ?: throw IllegalStateException("Folder unavailable")
                        cursor.use {
                            while (it.moveToNext()) {
                                val name = it.getString(1) ?: continue
                                if (it.getString(3) == DocumentsContract.Document.MIME_TYPE_DIR ||
                                    name.substringAfterLast('.', "").lowercase() !in extensions || it.getLong(2) > 100L * 1024 * 1024) continue
                                val document = DocumentsContract.buildDocumentUriUsingTree(tree, it.getString(0))
                                val file = java.io.File(cacheDir, "library-${document.toString().hashCode()}")
                                contentResolver.openInputStream(document)?.use { input ->
                                    file.outputStream().use { output ->
                                        val buffer = ByteArray(65536)
                                        var total = 0L
                                        while (true) {
                                            val count = input.read(buffer)
                                            if (count < 0) break
                                            total += count
                                            if (total > 100L * 1024 * 1024) throw IllegalStateException("Book exceeds 100 MB")
                                            output.write(buffer, 0, count)
                                        }
                                    }
                                } ?: throw IllegalStateException("Book unavailable")
                                result.add(mapOf("name" to name, "path" to file.absolutePath))
                            }
                        }
                        main.post { reply.success(result) }
                    } catch (e: Exception) { main.post { reply.error("folder", e.message, null) } }
                }
                else -> reply.notImplemented()
            }
        }
        observeFolder()
    }

    private fun observeFolder() {
        observedCursor?.close()
        observedCursor = null
        observer = null
        val tree = selected() ?: return
        try {
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
            observer = object : ContentObserver(main) {
                override fun onChange(selfChange: Boolean) { folderChannel.invokeMethod("changed", null) }
            }
            // Keeping the provider cursor open keeps its directory watcher
            // alive; the cursor forwards the provider's exact notification URI.
            observedCursor = contentResolver.query(children,
                arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID), null, null, null)?.also {
                it.registerContentObserver(observer)
            }
        } catch (_: Exception) { /* The library can retry when the app resumes. */ }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 9101) return
        val reply = pickerReply ?: return
        pickerReply = null
        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) { reply.success(false); return }
        try {
            contentResolver.takePersistableUriPermission(tree, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            val document = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
            val name = contentResolver.query(document, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst()) it.getString(0) else null
            } ?: DocumentsContract.getTreeDocumentId(tree)
            val previous = selected()
            preferences.edit().putString("tree", tree.toString()).putString("name", name).apply()
            observeFolder()
            if (previous != null && previous != tree) {
                try { contentResolver.releasePersistableUriPermission(previous, Intent.FLAG_GRANT_READ_URI_PERMISSION) } catch (_: Exception) { }
            }
            reply.success(true)
        } catch (e: Exception) { reply.error("folder", e.message, null) }
    }

    override fun onDestroy() {
        main.removeCallbacks(restoreBars)
        observedCursor?.close()
        pickerReply?.error("closed", null, null)
        pickerReply = null
        worker.shutdown()
        super.onDestroy()
    }
}
