import 'workspace_store.dart';
import 'native_workspace_store.dart'
    if (dart.library.js_interop) 'web_workspace_store.dart'
    as platform;

WorkspaceStore createWorkspaceStore() => platform.createWorkspaceStore();
