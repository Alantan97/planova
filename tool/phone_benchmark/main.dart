// Times the balanced (GA) planner on a real device and checks it still
// reproduces the Python GA's plans there. Not part of the app.
//
// Run on a connected phone (release build, as students would get it):
//   flutter run --release -d <device id> -t tool/phone_benchmark/main.dart
//
// It prints one "BENCH {...}" line per test week and a final
// "BENCH_DONE {...}" summary, then closes itself.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:planova/services/planning/balanced_plan_runner.dart';

import '../../test/support/scenario_io.dart';
import 'weeks.dart';

void main() => runApp(const _BenchmarkApp());

class _BenchmarkApp extends StatefulWidget {
  const _BenchmarkApp();
  @override
  State<_BenchmarkApp> createState() => _BenchmarkAppState();
}

class _BenchmarkAppState extends State<_BenchmarkApp> {
  String _status = 'Running…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    const repeats = 5;
    final medians = <double>[];
    final background = <double>[];
    var mismatches = 0;
    for (final (weekJson, expectedJson) in benchmarkWeeks) {
      final week = ScenarioWeek(jsonDecode(weekJson) as Map<String, dynamic>);
      final expected = jsonDecode(expectedJson) as Map<String, dynamic>;
      final request = PlanRequest(
        tasks: week.tasks,
        availability: week.availability,
        now: week.now,
        settings: week.settings,
      );

      // Warm-up run, also used for the parity check.
      final result = planBalancedFor(request);
      final same =
          jsonEncode(encodePlan(result.proposal)) ==
              jsonEncode({
                for (final key in ['from', 'to', 'sessions', 'unplaced'])
                  key: expected[key],
              }) &&
          result.score.total == expected['fitness'];
      if (!same) mismatches++;

      final times = <double>[];
      for (var i = 0; i < repeats; i++) {
        final watch = Stopwatch()..start();
        planBalancedFor(request);
        times.add(watch.elapsedMicroseconds / 1000);
      }
      times.sort();
      final median = times[repeats ~/ 2];
      medians.add(median);

      // What the student waits for: includes starting the background isolate.
      final watch = Stopwatch()..start();
      await planBalancedInBackground(request);
      final inBackground = watch.elapsedMicroseconds / 1000;
      background.add(inBackground);

      debugPrint(
        'BENCH ${jsonEncode({'week': week.id, 'medianMs': median, 'minMs': times.first, 'maxMs': times.last, 'backgroundMs': inBackground, 'matchesPython': same})}',
      );
      setState(
        () => _status = 'Done ${medians.length} of ${benchmarkWeeks.length}',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    medians.sort();
    background.sort();
    debugPrint(
      'BENCH_DONE ${jsonEncode({'weeks': medians.length, 'repeats': repeats, 'medianOfMediansMs': medians[medians.length ~/ 2], 'slowestMedianMs': medians.last, 'medianBackgroundMs': background[background.length ~/ 2], 'slowestBackgroundMs': background.last, 'mismatches': mismatches})}',
    );
    setState(() => _status = 'Finished');
    await Future<void>.delayed(const Duration(seconds: 2));
    exit(0);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: Text('GA benchmark\n$_status', textAlign: TextAlign.center),
      ),
    ),
  );
}
