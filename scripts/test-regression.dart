#!/usr/bin/env dart
/**
 * Regression Gate — pianolouvorja/mobile (Flutter)
 * Baseline: flutter test + flutter analyze
 * Build (apk/ios) fica nos jobs build-android/build-ios do CI
 * Uso:
 *   dart run scripts/test-regression.dart --baseline   (salva baseline)
 *   dart run scripts/test-regression.dart --compare    (compara; falha se regressão)
 */
import 'dart:io';
import 'dart:convert';

const BASELINE_FILE = '.regression-baseline.json';

void main(List<String> args) {
  final isBaseline = args.contains('--baseline');
  final isCompare = args.contains('--compare') || (!isBaseline && !args.contains('--baseline'));

  if (isBaseline) {
    print('📊 Salvando baseline de regressão (Flutter)...');
    final results = collectResults();
    saveBaseline(results);
    print('✅ Baseline salvo em $BASELINE_FILE');
    print('   Tests: passed=${results['tests']['passed']}, failed=${results['tests']['failed']}, skipped=${results['tests']['skipped']}');
    print('   Analyze: ${results['analyze']['ok'] ? "OK" : "FAIL"}');
    exit((results['tests']['failed'] > 0 || !results['analyze']['ok']) ? 1 : 0);
  }

  if (isCompare) {
    if (!File(BASELINE_FILE).existsSync()) {
      stderr.writeln('❌ Baseline não encontrado. Rode com --baseline primeiro.');
      exit(1);
    }
    final base = jsonDecode(File(BASELINE_FILE).readAsStringSync()) as Map<String, dynamic>;
    print('📊 Comparando com baseline...');

    final cur = collectResults();
    final failures = <String>[];

    if (cur['tests']['passed'] < base['tests']['passed'] || cur['tests']['failed'] > base['tests']['failed']) {
      failures.add('TESTS: baseline passed=${base['tests']['passed']} failed=${base['tests']['failed']} → atual passed=${cur['tests']['passed']} failed=${cur['tests']['failed']}');
    }
    if (base['analyze']['ok'] == true && cur['analyze']['ok'] != true) {
      failures.add('ANALYZE: baseline OK → atual FAIL');
    }

    if (failures.isNotEmpty) {
      stderr.writeln('❌ REGRESSÃO DETECTADA:');
      for (final f in failures) stderr.writeln('  - $f');
      exit(1);
    }
    print('✅ Sem regressão detectada.');
    exit(0);
  }
}

Map<String, dynamic> collectResults() {
  // 1) flutter test --machine (JSON streaming)
  final testResult = runProcess('flutter', ['test', '--machine']);
  Map<String, dynamic> testStats = {'passed': 0, 'failed': 0, 'skipped': 0};
  final lines = testResult['out'].split('\n');
  for (final line in lines) {
    if (line.trim().isEmpty) continue;
    try {
      final data = jsonDecode(line) as Map<String, dynamic>;
      if (data['type'] == 'testDone' && data['hidden'] != true) {
        if (data['skipped'] == true) {
          testStats['skipped'] = (testStats['skipped'] as int) + 1;
        } else if (data['result'] == 'success') {
          testStats['passed'] = (testStats['passed'] as int) + 1;
        } else {
          testStats['failed'] = (testStats['failed'] as int) + 1;
        }
      }
    } catch (_) {}
  }

  // 2) flutter analyze (alinhar com CI: --fatal-warnings --no-fatal-infos)
  final analyzeResult = runProcess('flutter', ['analyze', '--fatal-warnings', '--no-fatal-infos']);
  final analyzeOk = analyzeResult['ok'];

  return {
    'tests': testStats,
    'analyze': {'ok': analyzeOk, 'err': analyzeOk ? '' : 'analyze falhou — rodar flutter analyze para detalhes'},
  };
}

Map<String, dynamic> runProcess(String executable, List<String> args) {
  try {
    final process = Process.runSync(executable, args, runInShell: true);
    return {
      'ok': process.exitCode == 0,
      'out': process.stdout.toString(),
      'err': process.stderr.toString(),
    };
  } catch (e) {
    return {'ok': false, 'out': '', 'err': e.toString()};
  }
}

void saveBaseline(Map<String, dynamic> results) {
  File(BASELINE_FILE).writeAsStringSync(JsonEncoder.withIndent('  ').convert(results));
}
