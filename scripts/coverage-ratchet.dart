// Coverage ratchet: bloqueia PR se a cobertura de linhas do lcov cair
// em relação ao baseline commitado. Uso:
//   dart run scripts/coverage_ratchet.dart [baseline.txt]
// O baseline é "NN.NN" (uma linha). Para renovar: --update grava o novo valor.
import 'dart:io';

Future<void> main(List<String> args) async {
  final lcov = File('coverage/lcov.info');
  if (!lcov.existsSync()) {
    stderr.writeln('coverage/lcov.info não encontrado — rode flutter test --coverage');
    exit(2);
  }

  var hit = 0, total = 0;
  for (final line in lcov.readAsLinesSync()) {
    if (line.startsWith('LF:')) total += int.parse(line.substring(3));
    if (line.startsWith('LH:')) hit += int.parse(line.substring(3));
  }
  if (total == 0) {
    stderr.writeln('lcov sem linhas medidas');
    exit(2);
  }
  final current = hit * 100 / total;
  final pct = current.toStringAsFixed(2);
  stdout.writeln('Cobertura atual (linhas): $pct% ($hit/$total)');

  final update = args.contains('--update');
  final baselinePath = args.where((a) => !a.startsWith('--')).firstOrNull ?? 'scripts/coverage-baseline.txt';

  if (update) {
    File(baselinePath).writeAsStringSync('$pct\n');
    stdout.writeln('Baseline atualizado: $pct%');
    exit(0);
  }

  final baseFile = File(baselinePath);
  if (!baseFile.existsSync()) {
    stderr.writeln('Baseline ausente: $baselinePath — gere com --update');
    exit(2);
  }
  final baseline = double.parse(baseFile.readAsStringSync().trim());

  // Tolerância 0.5%: o Flutter do CI pode medir ligeiramente diferente do local
  // (versão do engine, ordem de shards). Regressão real é bem maior que isso.
  const tolerance = 0.5;
  if (current < baseline - tolerance) {
    stderr.writeln('❌ Coverage REGREDIU: $pct% < baseline $baseline%');
    exit(1);
  }
  stdout.writeln('✅ Coverage OK: $pct% >= baseline $baseline% (tolerância 0.5%)');
  if (current > baseline + tolerance) {
    stdout.writeln('ℹ️ Subiu! Renove o baseline com --update para travar o ganho.');
  }
}
