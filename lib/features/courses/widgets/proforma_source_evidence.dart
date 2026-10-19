import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/proforma.dart';

class ProformaSourceEvidence extends StatelessWidget {
  const ProformaSourceEvidence({super.key, required this.source});
  final ProformaSource source;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: PageStorageKey(
      'evidence-${source.fingerprint}-${source.rowId}-${source.page}',
    ),
    tilePadding: EdgeInsets.zero,
    title: Text(
      'Source · page ${source.page}',
      style: const TextStyle(fontSize: 13),
    ),
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SelectableText(
          source.excerpt,
          key: PageStorageKey(
            'evidence-text-${source.fingerprint}-${source.rowId}-${source.page}',
          ),
          style: const TextStyle(color: planovaMuted, height: 1.5),
        ),
      ),
    ],
  );
}
