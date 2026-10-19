import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_dependencies.dart';
import 'app_shell.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.dependencies, this.loadDependencies});
  final AppDependencies? dependencies;
  final Future<AppDependencies> Function()? loadDependencies;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AppDependencies? _dependencies;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _dependencies = widget.dependencies;
    if (_dependencies == null) unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loadFailed = false);
    try {
      final dependencies =
          await (widget.loadDependencies ?? AppDependencies.local)();
      if (!mounted) {
        await dependencies.close();
        return;
      }
      setState(() => _dependencies = dependencies);
    } catch (error) {
      debugPrint('Could not open Planova task storage: $error');
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    if (widget.dependencies == null && _dependencies != null) {
      unawaited(_dependencies!.close());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Planova',
    debugShowCheckedModeBanner: false,
    theme: buildPlanovaTheme(),
    home: _dependencies != null
        ? AppShell(dependencies: _dependencies!)
        : Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _loadFailed
                        ? [
                            const Icon(
                              Icons.storage_rounded,
                              color: planovaOrange,
                              size: 40,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Could not open saved tasks',
                              style: Theme.of(context).textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Your saved data has not been reset. Try again, or restart the app.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: () => unawaited(_load()),
                              child: const Text('Retry'),
                            ),
                          ]
                        : [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 16),
                            const Text('Opening Planova…'),
                          ],
                  ),
                ),
              ),
            ),
          ),
  );
}
