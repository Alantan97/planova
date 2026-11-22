import 'package:flutter/widgets.dart';

/// Whether the student turned on experimental features (Profile → About):
/// the unvalidated task-ranking model and weekly learning topics from
/// proformas. Off by default, so students only see finished features.
///
/// Provided once above every route, so any screen can ask without passing a
/// flag through each constructor.
class ExperimentalFeatures extends InheritedWidget {
  const ExperimentalFeatures({
    super.key,
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  /// False when no value is provided (for example, a screen tested alone).
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ExperimentalFeatures>()
          ?.enabled ??
      false;

  @override
  bool updateShouldNotify(ExperimentalFeatures oldWidget) =>
      enabled != oldWidget.enabled;
}
