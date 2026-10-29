package org.orbitnote.app

import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.util.Locale
import java.util.UUID

/** Copy only the explicitly selected tree. No source writes or executable recovery. */
internal class VaultFolderImporter(
    private val source: Source,
    private val destination: File,
    private val validateManifest: (ByteArray) -> Unit,
    private val maxBytes: Long = 8L * 1024 * 1024 * 1024,
) {
    data class Entry(val id: String, val name: String, val directory: Boolean,
                     val size: Long = -1, val modified: Long = 0)
    interface Source {
        fun children(id: String): List<Entry>
        fun stat(id: String): Entry
        fun read(id: String): InputStream
    }
    private data class Planned(val entry: Entry, val path: String)

    fun import(rootId: String): File {
        val token = UUID.randomUUID().toString()
        val planned = mutableListOf<Planned>()
        val seen = mutableSetOf(rootId)
        val paths = mutableSetOf<String>()
        var estimated = 0L
        fun visit(id: String, parent: String, depth: Int) {
            check(depth <= 64) { "The selected folder is too deeply nested." }
            for (entry in source.children(id)) {
                check(planned.size < 100000) { "The selected folder has too many entries." }
                portableName(entry.name)
                val relative = if (parent.isEmpty()) entry.name else "$parent/${entry.name}"
                if (excluded(relative)) continue
                check(seen.add(entry.id)) { "The selected folder contains repeated or cyclic entries." }
                val path = if (relative == ".orbit/recovery" || relative.startsWith(".orbit/recovery/")) {
                    ".orbit/imported-recovery/$token" + relative.removePrefix(".orbit/recovery")
                } else relative
                check(paths.add(path.lowercase(Locale.ROOT))) { "The selected folder contains colliding names." }
                planned.add(Planned(entry, path))
                if (entry.directory) visit(entry.id, relative, depth + 1)
                else if (entry.size > 0) {
                    check(entry.size <= maxBytes - estimated) { "The selected Vault exceeds the import size limit." }
                    estimated += entry.size
                }
            }
        }
        visit(rootId, "", 0)
        val manifest = planned.singleOrNull { it.path == "workspace.json" && !it.entry.directory }
            ?: error("Select the Vault folder containing workspace.json, not its parent or a Notes folder.")
        val originalManifest = source.read(manifest.entry.id).use { input ->
            val output = java.io.ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            while (output.size() <= 1024 * 1024) {
                val count = input.read(buffer, 0, minOf(buffer.size, 1024 * 1024 + 1 - output.size()))
                if (count < 0) break
                output.write(buffer, 0, count)
            }
            output.toByteArray()
        }
        check(originalManifest.size <= 1024 * 1024) { "The Vault manifest is too large." }
        validateManifest(originalManifest)
        check(destination.isDirectory || destination.mkdirs()) { "Local Vault storage is unavailable." }
        check(destination.usableSpace > estimated + 8 * 1024 * 1024) { "Not enough free space for this Vault." }
        val stage = File(destination, ".importing-$token")
        val target = File(destination, "Imported Vault $token")
        check(stage.mkdir()) { "Could not prepare local Vault storage." }
        var copied = 0L
        try {
            for ((entry, path) in planned) {
                val file = File(stage, path)
                check(file.canonicalPath.startsWith(stage.canonicalPath + File.separator)) { "Unsafe import path." }
                if (entry.directory) {
                    check(file.isDirectory || file.mkdirs()) { "Could not create an imported folder." }
                } else {
                    check(!file.exists()) { "An imported file collides with another entry." }
                    check(file.parentFile!!.isDirectory || file.parentFile!!.mkdirs()) { "Could not create an imported folder." }
                    var length = 0L
                    source.read(entry.id).use { input ->
                        FileOutputStream(file).use { output ->
                            val buffer = ByteArray(64 * 1024)
                            while (true) {
                                val count = input.read(buffer)
                                if (count < 0) break
                                check(count.toLong() <= maxBytes - copied) { "The selected Vault exceeds the import size limit." }
                                check(destination.usableSpace > count + 8 * 1024 * 1024) { "Not enough free space for this Vault." }
                                output.write(buffer, 0, count)
                                copied += count
                                length += count
                            }
                            output.fd.sync()
                        }
                    }
                    val after = source.stat(entry.id)
                    check((entry.size < 0 || length == entry.size) &&
                        (after.size < 0 || length == after.size) &&
                        (entry.modified == 0L || after.modified == entry.modified)) {
                        "The source Vault changed during import. Close it in the other app and retry."
                    }
                }
            }
            check(File(stage, "workspace.json").readBytes().contentEquals(originalManifest)) {
                "The source Vault manifest changed during import. Retry with the other app closed."
            }
            check(!target.exists() && stage.renameTo(target)) { "Could not finish the local Vault import." }
            return target
        } catch (error: Throwable) {
            // Only this newly allocated staging directory is eligible for cleanup.
            if (stage.canonicalFile.parentFile == destination.canonicalFile && stage.name == ".importing-$token") {
                stage.deleteRecursively()
            }
            throw error
        }
    }

    companion object {
        fun portableName(name: String) {
            check(name.isNotEmpty() && name != "." && name != ".." &&
                !name.endsWith('.') && !name.endsWith(' ') &&
                name.none { it.code < 32 || it in "<>:\"/\\|?*" } &&
                !Regex("(?i)^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\\.|$).*").matches(name)) {
                "The selected folder contains an unsafe or nonportable name."
            }
        }
        fun excluded(path: String): Boolean = path == ".orbit/device" || path.startsWith(".orbit/device/") ||
            path == ".orbit/cache" || path.startsWith(".orbit/cache/") || path.startsWith(".orbit/workspace.sqlite")
    }
}
