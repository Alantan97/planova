import 'package:flutter/material.dart';

import '../../core/time/app_clock.dart';
import '../../data/repositories/task_repository.dart';
import 'screens/courses_screen.dart';
import 'screens/proforma_import_screen.dart';

/// One entry point for "Import proforma" outside Courses & semesters.
///
/// A proforma belongs to a semester, so:
/// - no semester yet → open Courses & semesters to add one first;
/// - one semester → go straight to import;
/// - several → ask which semester.
Future<void> startProformaImport(
  BuildContext context,
  TaskRepository repository,
  AppClock clock,
) async {
  final semesters = repository.semesters;
  if (semesters.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Add your semester first, then import its proformas.'),
      ),
    );
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CoursesScreen(repository: repository, clock: clock),
      ),
    );
    return;
  }
  final semesterId = semesters.length == 1
      ? semesters.single.id
      : await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    'Import into which semester?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                for (final semester in semesters)
                  ListTile(
                    key: ValueKey('import-semester-${semester.id}'),
                    leading: const Icon(Icons.school_outlined),
                    title: Text(semester.name),
                    onTap: () => Navigator.pop(context, semester.id),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
  if (semesterId == null || !context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ProformaImportScreen(
        repository: repository,
        clock: clock,
        semesterId: semesterId,
      ),
    ),
  );
}
