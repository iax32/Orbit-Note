package org.orbitnote.app

import org.junit.Assert.*
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.File
import java.io.IOException
import java.nio.file.Files

class VaultFolderImporterTest {
    private class Tree : VaultFolderImporter.Source {
        val nodes = linkedMapOf<String, VaultFolderImporter.Entry>()
        val data = mutableMapOf<String, ByteArray>()
        var broken: String? = null
        var changed: String? = null
        init { file("workspace.json", "manifest-1"); folder("Notes"); file("Notes/a.md", "Note bytes") }
        fun folder(path: String) { nodes[path] = VaultFolderImporter.Entry(path, path.substringAfterLast('/'), true) }
        fun file(path: String, text: String) {
            data[path] = text.toByteArray()
            nodes[path] = VaultFolderImporter.Entry(path, path.substringAfterLast('/'), false, data[path]!!.size.toLong(), 123)
        }
        override fun children(id: String) = nodes.values.filter { it.id.substringBeforeLast('/', "root") == id }
        override fun stat(id: String) = nodes.getValue(id).let { if (id == changed) it.copy(modified = 999) else it }
        override fun read(id: String) = if (id == broken) throw IOException("provider unavailable") else ByteArrayInputStream(data.getValue(id))
    }
    private fun run(tree: Tree = Tree(), maxBytes: Long = 1024 * 1024, test: (File, File) -> Unit) {
        val root = Files.createTempDirectory("orbit-vault-import-test").toFile()
        val destination = File(root, "vaults")
        try {
            val imported = VaultFolderImporter(tree, destination, { require(it.isNotEmpty()) }, maxBytes).import("root")
            test(imported, destination)
        } finally { root.deleteRecursively() }
    }
    @Test fun preservesBytesUnknownFilesAndIdentityAcrossRepeatedImports() {
        val tree = Tree().apply { folder("Boards"); file("Boards/future.board.json", "opaque future data"); file("custom.bin", "unknown") }
        run(tree) { imported, destination ->
            assertEquals("manifest-1", File(imported, "workspace.json").readText())
            assertEquals("opaque future data", File(imported, "Boards/future.board.json").readText())
            val second = VaultFolderImporter(tree, destination, {}).import("root")
            assertNotEquals(imported, second)
            assertEquals("unknown", File(second, "custom.bin").readText())
            assertEquals("Note bytes", String(tree.data.getValue("Notes/a.md")))
        }
    }
    @Test fun excludesOtherDeviceStateAndQuarantinesExecutableRecovery() {
        val tree = Tree().apply {
            folder(".orbit"); folder(".orbit/device"); file(".orbit/device/secret.json", "device")
            folder(".orbit/cache"); file(".orbit/cache/preview.png", "cache")
            file(".orbit/workspace.sqlite-wal", "index")
            folder(".orbit/history"); file(".orbit/history/version.json", "history")
            folder(".orbit/recovery"); file(".orbit/recovery/delete-test.json", "do not execute")
        }
        run(tree) { imported, _ ->
            assertFalse(File(imported, ".orbit/device").exists())
            assertFalse(File(imported, ".orbit/workspace.sqlite-wal").exists())
            assertFalse(File(imported, ".orbit/recovery").exists())
            assertEquals("history", File(imported, ".orbit/history/version.json").readText())
            assertEquals("do not execute", File(imported, ".orbit/imported-recovery").walkTopDown().single { it.isFile }.readText())
        }
    }
    @Test fun refusesTraversalAndCaseCollisions() {
        for (name in listOf("../escape", "..", "/absolute", "A.md", "con.txt")) {
            val tree = Tree()
            tree.file("a.md", "a")
            tree.nodes["bad"] = VaultFolderImporter.Entry("bad", name, false)
            assertThrows(IllegalStateException::class.java) { run(tree) { _, _ -> fail() } }
        }
    }
    @Test fun refusesProviderCycles() {
        val tree = Tree()
        tree.nodes["cycle"] = VaultFolderImporter.Entry("Notes", "cycle", true)
        assertThrows(IllegalStateException::class.java) { run(tree) { _, _ -> fail() } }
    }
    @Test fun missingManifestDoesNotCreateAVault() {
        val tree = Tree().apply { nodes.remove("workspace.json") }
        assertThrows(IllegalStateException::class.java) { run(tree) { _, _ -> fail() } }
    }
    @Test fun failedOrChangedCopiesNeverPublishPartialVaults() {
        for (changed in listOf(false, true)) {
            val root = Files.createTempDirectory("orbit-vault-failure-test").toFile()
            val destination = File(root, "vaults")
            val tree = Tree().apply { if (changed) this.changed = "Notes/a.md" else broken = "Notes/a.md" }
            try {
                try { VaultFolderImporter(tree, destination, {}).import("root"); fail() } catch (_: Exception) {}
                assertTrue(destination.listFiles().orEmpty().isEmpty())
                assertEquals("Note bytes", String(tree.data.getValue("Notes/a.md")))
            } finally { root.deleteRecursively() }
        }
    }
    @Test fun enforcesSizeLimitBeforePublication() {
        assertThrows(IllegalStateException::class.java) { run(maxBytes = 3) { _, _ -> fail() } }
    }
    @Test fun readableNamesPreserveOriginalAndUseNumberedCopies() {
        val root = Files.createTempDirectory("orbit-vault-names").toFile()
        try {
            val importer = VaultFolderImporter(Tree(), root, {}, manifestName = { "Analysis / Übung" })
            val first = importer.import("root")
            val second = importer.import("root")
            assertEquals("Analysis Übung", first.name)
            assertEquals("Analysis Übung (2)", second.name)
            assertEquals("manifest-1", File(first, "workspace.json").readText())
            assertEquals("Vault CON", VaultFolderImporter.folderName("CON"))
            assertEquals("Vault", VaultFolderImporter.folderName(".."))
        } finally { root.deleteRecursively() }
    }
    @Test fun invalidManifestNeverPublishes() {
        val root = Files.createTempDirectory("orbit-vault-manifest-test").toFile()
        try {
            val destination = File(root, "vaults")
            assertThrows(IllegalArgumentException::class.java) {
                VaultFolderImporter(Tree(), destination, { error -> require(error.isEmpty()) }).import("root")
            }
            assertFalse(destination.exists())
        } finally { root.deleteRecursively() }
    }
}
