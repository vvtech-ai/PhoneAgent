import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import '../domain/document_import.dart';

class PlatformDocumentPicker implements DocumentPicker {
  const PlatformDocumentPicker();
  @override
  Future<List<SelectedDocument>> pick() async {
    final files = await openFiles(
      acceptedTypeGroups: [
        XTypeGroup(
          label: 'Word / Excel',
          extensions: const ['docx', 'xlsx'],
          mimeTypes: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
              ? const ['application/*']
              : const [
                  'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                ],
          uniformTypeIdentifiers: const [
            'org.openxmlformats.wordprocessingml.document',
            'org.openxmlformats.spreadsheetml.sheet',
          ],
        ),
      ],
    );
    return [
      for (final file in files)
        SelectedDocument(
          name: file.name,
          mimeType:
              file.mimeType ??
              (file.name.toLowerCase().endsWith('.xlsx')
                  ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                  : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'),
          size: await file.length(),
          read: file.readAsBytes,
        ),
    ];
  }
}
