import '../domain/code_project.dart';

/// One explicit sequence. Cancellation and context are checked between steps.
class CodeProfileRun {
  bool cancelled = false;
  void cancel() => cancelled = true;
  Future<int?> run(
    List<ToolCommand> commands, {
    required Future<int?> Function(ToolCommand) execute,
    required Future<bool> Function() canContinue,
    void Function(int, int)? onStep,
  }) async {
    for (var i = 0; i < commands.length; i++) {
      if (cancelled || !await canContinue() || cancelled) return null;
      onStep?.call(i + 1, commands.length);
      final exit = await execute(commands[i]);
      if (cancelled || exit != 0) return cancelled ? null : exit;
    }
    return 0;
  }
}
