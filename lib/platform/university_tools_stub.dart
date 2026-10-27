import '../domain/code_project.dart';
import '../domain/university/protocol_lab.dart';

bool get universityToolsSupported => false;
Future<LabProtocolConnection> connectUniversityProtocol(
  String host,
  int port,
) async => throw UnsupportedError('TCP tools require a native desktop app.');
Future<CodeToolProcess> verifyUniversityDafny(
  String executable,
  String source,
) async => throw UnsupportedError('Dafny requires a native desktop toolchain.');
