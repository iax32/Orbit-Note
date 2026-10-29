package org.orbitnote.app

import android.app.Activity
import android.content.Intent
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.util.concurrent.Executors

/** SAF streams retain the user's selected-tree permission; raw paths do not. */
internal class AndroidVaultFolderPicker(private val activity: Activity) {
    private var pending: MethodChannel.Result? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val requestCode = 47912

    fun open(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("vault_busy", "A Vault folder import is already running.", null)
            return
        }
        pending = result
        try {
            activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
            }, requestCode)
        } catch (_: Exception) {
            pending = null
            result.error("vault_picker", "Android could not open the folder picker.", null)
        }
    }

    fun onResult(request: Int, resultCode: Int, data: Intent?): Boolean {
        if (request != requestCode) return false
        val result = pending ?: return true
        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            pending = null
            result.success(null)
            return true
        }
        executor.execute {
            try {
                val resolver = activity.contentResolver
                val projection = arrayOf(Document.COLUMN_DOCUMENT_ID, Document.COLUMN_DISPLAY_NAME,
                    Document.COLUMN_MIME_TYPE, Document.COLUMN_SIZE, Document.COLUMN_LAST_MODIFIED)
                fun entry(cursor: android.database.Cursor) = VaultFolderImporter.Entry(
                    cursor.getString(0), cursor.getString(1),
                    cursor.getString(2) == Document.MIME_TYPE_DIR,
                    if (cursor.isNull(3)) -1 else cursor.getLong(3),
                    if (cursor.isNull(4)) 0 else cursor.getLong(4))
                fun document(id: String) = DocumentsContract.buildDocumentUriUsingTree(tree, id)
                val source = object : VaultFolderImporter.Source {
                    override fun children(id: String): List<VaultFolderImporter.Entry> {
                        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, id)
                        return resolver.query(uri, projection, null, null, null)?.use { cursor ->
                            buildList { while (cursor.moveToNext()) add(entry(cursor)) }
                        } ?: error("Android could not read the selected folder.")
                    }
                    override fun stat(id: String): VaultFolderImporter.Entry =
                        resolver.query(document(id), projection, null, null, null)?.use { cursor ->
                            check(cursor.moveToFirst()) { "An imported file is no longer available." }
                            entry(cursor)
                        } ?: error("Android could not verify an imported file.")
                    override fun read(id: String) = resolver.openInputStream(document(id))
                        ?: error("Android could not read an imported file.")
                }
                val importer = VaultFolderImporter(source, File(activity.filesDir, "vaults"), { bytes ->
                    val manifest = JSONObject(bytes.toString(Charsets.UTF_8))
                    check(manifest.optString("format") == "orbit-note-workspace" &&
                        manifest.opt("version") is Int && manifest.optString("id").isNotEmpty()) {
                        "This folder does not contain a valid Orbit Vault manifest."
                    }
                    // Storage versions, not app build numbers, govern compatibility.
                    // Repository opening retains its normal future-version read-only rules.
                })
                val path = importer.import(DocumentsContract.getTreeDocumentId(tree)).absolutePath
                activity.runOnUiThread { pending = null; result.success(path) }
            } catch (error: Exception) {
                val message = when (error) {
                    is SecurityException -> "Android denied folder access. Select the Vault folder again and allow access."
                    is IllegalStateException -> error.message ?: "The Vault could not be imported."
                    else -> "The Vault folder could not be imported. Check free space and folder access, then retry."
                }
                activity.runOnUiThread { pending = null; result.error("vault_import", message, null) }
            }
        }
        return true
    }
}
