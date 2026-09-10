import 'object_index.dart';
import 'native_object_index.dart'
    if (dart.library.js_interop) 'memory_object_index.dart'
    as platform;

ObjectIndex createObjectIndex() => platform.createObjectIndex();
