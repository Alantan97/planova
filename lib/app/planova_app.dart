import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'app_dependencies.dart';
import 'app_shell.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.dependencies});
  final AppDependencies? dependencies;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppDependencies _dependencies =
      widget.dependencies ?? AppDependencies.demo();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Planova',
    debugShowCheckedModeBanner: false,
    theme: buildPlanovaTheme(),
    home: AppShell(dependencies: _dependencies),
  );
}
