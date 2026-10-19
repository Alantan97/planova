import 'package:flutter/material.dart';

import '../../../core/errors/academic_save_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/time/app_clock.dart';
import '../../../core/widgets/study_components.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../models/proforma.dart';
import '../../../services/proforma/proforma_import_service.dart';
import 'proforma_review_screen.dart';

class ProformaImportScreen extends StatefulWidget {
  const ProformaImportScreen({
    super.key,
    required this.repository,
    required this.clock,
    required this.semesterId,
    this.loadDocument,
  });
  final TaskRepository repository;
  final AppClock clock;
  final String semesterId;
  final Future<ProformaDraft?> Function()? loadDocument;
  @override
  State<ProformaImportScreen> createState() => _ProformaImportScreenState();
}

class _ProformaImportScreenState extends State<ProformaImportScreen> {
  bool _loading = false;
  String? _error;
  ProformaDraft? _draft;
  Future<void> _choose() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final draft =
          await (widget.loadDocument ??
              ProformaImportService().pickAndExtract)();
      if (mounted && draft != null) setState(() => _draft = draft);
    } catch (error) {
      if (mounted) setState(() => _error = academicSaveError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_draft != null) {
      return ProformaReviewScreen(
        key: ValueKey(_draft),
        repository: widget.repository,
        clock: widget.clock,
        semesterId: widget.semesterId,
        draft: _draft!,
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Import proforma')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                FeaturedPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          Icons.upload_file_outlined,
                          size: 30,
                          color: planovaOrange,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Your course, with a head start.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Choose a text-based UPSI course proforma. Review the course and assessment drafts before anything is saved.',
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.5,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _loading ? null : _choose,
                        style: FilledButton.styleFrom(
                          disabledBackgroundColor: Colors.white12,
                          disabledForegroundColor: Colors.white60,
                        ),
                        icon: const Icon(Icons.folder_open_outlined),
                        label: Text(
                          _error == null ? 'Choose PDF' : 'Try another PDF',
                        ),
                      ),
                      if (_loading) ...[
                        const SizedBox(height: 16),
                        const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Reading PDF and preparing drafts…',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Supported now: the bilingual Course Info and Continuous / Final Assessment table format. Scans, weekly topics and automatic scheduling are not supported in this increment.',
                  style: TextStyle(height: 1.5),
                ),
                const SizedBox(height: 16),
                const Text(
                  'The PDF is read on this device and is not uploaded or kept in Planova’s database. Only confirmed fields and short source references are saved. Limit: 10 MB, 40 pages.',
                  style: TextStyle(height: 1.5, color: planovaMuted),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
