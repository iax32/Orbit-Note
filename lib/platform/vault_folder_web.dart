Future<String> createVaultFolder(String parent, String name) async =>
    throw UnsupportedError('Folder Vaults are available on desktop.');

Future<String> createLocalVaultFolder(String name) async =>
    throw UnsupportedError('Local folders are unavailable in the browser.');
