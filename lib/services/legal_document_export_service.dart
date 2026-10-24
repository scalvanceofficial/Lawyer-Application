import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'generated_file_service.dart';

class LegalDocumentExportService {
  const LegalDocumentExportService._();

  static Future<GeneratedFile> createPdf({
    required String title,
    required String content,
    Directory? directory,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('DOCUMENT CONTENT LENGTH: ${content.length}');
        debugPrint('DOCUMENT CONTENT: $content');
      }
      if (content.trim().isEmpty) {
        throw const LegalDocumentExportException(
          'The generated document content is empty.',
        );
      }
      final fonts = await _loadFonts();
      final document = pw.Document(
        title: title,
        author: 'NyaySaarthi',
        creator: 'NyaySaarthi',
        theme: pw.ThemeData.withFont(
          base: fonts.regular,
          bold: fonts.bold,
          fontFallback: [fonts.devanagari, fonts.devanagariBold],
        ),
      );
      final cleaned = _clean(content);
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(42),
          header: (context) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.brown300),
              ),
            ),
            child: pw.Text(
              'NYAYSAARTHI',
              style: pw.TextStyle(
                color: PdfColors.brown700,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 9),
            ),
          ),
          build: (context) => [
            pw.SizedBox(height: 18),
            pw.Text(
              title,
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 18),
            ..._contentWidgets(cleaned),
            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 8),
            pw.Text(
              'Generated with NyaySaarthi. This draft provides general legal information and should be reviewed by a qualified advocate before use.',
              style: const pw.TextStyle(
                color: PdfColors.grey700,
                fontSize: 9,
                height: 1.35,
              ),
            ),
          ],
        ),
      );

      final Uint8List bytes = await document.save();
      debugPrint('PDF RENDERED BYTE SIZE: ${bytes.length}');
      if (bytes.isEmpty) {
        throw const LegalDocumentExportException(
          'The PDF renderer returned zero bytes.',
        );
      }
      final file = await GeneratedFileService.saveBytes(
        bytes: bytes,
        fileName: _fileName(title),
        directory: directory,
      );
      debugPrint('PDF PATH: ${file.path}');
      debugPrint('PDF EXISTS: true');
      debugPrint('PDF SIZE: ${file.size}');
      return file;
    } catch (error, stackTrace) {
      debugPrint('PDF GENERATION ERROR: $error');
      debugPrint('PDF STACK TRACE: $stackTrace');
      rethrow;
    }
  }

  static Future<_PdfFonts> _loadFonts() async {
    try {
      final regular = await rootBundle.load(
        'assets/fonts/NotoSans-Regular.ttf',
      );
      final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
      final devanagari = await rootBundle.load(
        'assets/fonts/NotoSansDevanagari-Regular.ttf',
      );
      final devanagariBold = await rootBundle.load(
        'assets/fonts/NotoSansDevanagari-Bold.ttf',
      );
      debugPrint(
        'PDF FONT BYTE SIZES: ${[regular.lengthInBytes, bold.lengthInBytes, devanagari.lengthInBytes, devanagariBold.lengthInBytes].join(', ')}',
      );
      return _PdfFonts(
        regular: pw.Font.ttf(regular),
        bold: pw.Font.ttf(bold),
        devanagari: pw.Font.ttf(devanagari),
        devanagariBold: pw.Font.ttf(devanagariBold),
      );
    } catch (error, stackTrace) {
      debugPrint('PDF FONT LOAD ERROR: $error');
      debugPrint('PDF FONT STACK TRACE: $stackTrace');
      rethrow;
    }
  }

  static String _clean(String value) => value
      .replaceAll(RegExp(r'\[[^\]]+\]\(sandbox:[^)]+\)'), '')
      .replaceAll(RegExp(r'```[^\n]*\n?'), '')
      .replaceAll('```', '')
      .trim();

  static List<pw.Widget> _contentWidgets(String content) {
    final widgets = <pw.Widget>[];
    final paragraph = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Text(
            paragraph.join(' ').replaceAll('**', '').trim(),
            style: const pw.TextStyle(fontSize: 11, height: 1.5),
          ),
        ),
      );
      paragraph.clear();
    }

    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        flushParagraph();
        continue;
      }
      final heading = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
      if (heading != null) {
        flushParagraph();
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8, bottom: 7),
            child: pw.Text(
              heading.group(2)!.replaceAll('**', ''),
              style: pw.TextStyle(
                fontSize: heading.group(1)!.length == 1 ? 16 : 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        );
        continue;
      }
      final bullet = RegExp(r'^(?:[-*•]|\d+[.)])\s+(.+)$').firstMatch(line);
      if (bullet != null) {
        flushParagraph();
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 10, bottom: 5),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('-  ', style: const pw.TextStyle(fontSize: 11)),
                pw.Expanded(
                  child: pw.Text(
                    bullet.group(1)!.replaceAll('**', ''),
                    style: const pw.TextStyle(fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      final isShortHeading =
          line.length < 70 &&
          (line.endsWith(':') ||
              (line == line.toUpperCase() && RegExp('[A-Z]').hasMatch(line)));
      if (isShortHeading) {
        flushParagraph();
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 7, bottom: 5),
            child: pw.Text(
              line.replaceAll('**', ''),
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          ),
        );
      } else {
        paragraph.add(line);
      }
    }
    flushParagraph();
    return widgets;
  }

  static String _fileName(String title) {
    final words = title
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), ' ')
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join('_');
    return '${words.isEmpty ? 'Legal_Document' : words}.pdf';
  }
}

class _PdfFonts {
  const _PdfFonts({
    required this.regular,
    required this.bold,
    required this.devanagari,
    required this.devanagariBold,
  });

  final pw.Font regular;
  final pw.Font bold;
  final pw.Font devanagari;
  final pw.Font devanagariBold;
}

class LegalDocumentExportException implements Exception {
  const LegalDocumentExportException(this.message);
  final String message;

  @override
  String toString() => message;
}
