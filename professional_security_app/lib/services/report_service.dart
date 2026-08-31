import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/profile.dart';
import '../models/work_session.dart';
import 'arabic_shaping.dart';

class ReportServiceException implements Exception {
  final String message;
  ReportServiceException(this.message);

  @override
  String toString() => message;
}

/// Builds a one-employee, one-month PDF work-hours report (dates,
/// workplace, start/end, duration, verification status - per
/// requirements-and-architecture_V1.md FR-036) and hands it to the
/// device's native share sheet (Printing.sharePdf) so the admin can save
/// or send it - the standard cross-platform way to "download" a
/// generated file on Android/iOS without extra storage permissions.
class ReportService {
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  // Hebrew letters/points, U+0591-U+05F4. Built from a raw code point
  // range (rather than a \uXXXX escape typed directly into the source) to
  // avoid any risk of the literal escape sequence being silently swapped
  // for the actual character while this file was being edited.
  static final _hebrewPattern = RegExp(
    '[${String.fromCharCode(0x0591)}-${String.fromCharCode(0x05F4)}]',
  );

  /// Renders [text] right-to-left when it needs to be - Arabic and Hebrew
  /// need two different mechanisms here:
  ///
  /// - Arabic goes through shapeArabicForDisplay() (see
  ///   arabic_shaping.dart) and is then handed to pw.Text with NO
  ///   textDirection override, since that function already returns the
  ///   text pre-shaped and pre-reordered for plain left-to-right display.
  ///   This bypasses the pdf package's own Arabic shaping entirely - it
  ///   has a real bug (confirmed independent of font choice) where every
  ///   occurrence of a letter like م (MEEM) always renders in its
  ///   isolated form no matter its position, breaking any word where
  ///   that letter needs to connect to a neighbour.
  /// - Hebrew doesn't have that problem - the pdf package's own
  ///   textDirection: rtl handling reorders it correctly on its own
  ///   (Hebrew letters don't change shape by position the way Arabic
  ///   ones do, so there's no shaping table for it to get wrong) - so it
  ///   keeps using that existing mechanism.
  pw.Widget _bidiText(String text, {pw.TextStyle? style}) {
    if (containsArabic(text)) {
      return pw.Text(shapeArabicForDisplay(text), style: style);
    }
    if (_hebrewPattern.hasMatch(text)) {
      return pw.Text(text, textDirection: pw.TextDirection.rtl, style: style);
    }
    return pw.Text(text, style: style);
  }

  /// The base14 fonts pdf.Document() uses by default only cover Latin
  /// script - without an explicit fallback, any Arabic/Hebrew character
  /// (an employee's name, a workplace name) has no glyph to draw and
  /// renders as a missing-glyph box. These two Noto fonts (OFL-licensed,
  /// bundled under assets/fonts/) are wired in as fallbacks so the default
  /// Latin font is used whenever possible and Noto only kicks in for the
  /// characters it's actually needed for.
  Future<List<pw.Font>> _loadFallbackFonts() async {
    final arabic = await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
    final hebrew = await rootBundle.load('assets/fonts/NotoSansHebrew-Regular.ttf');
    return [pw.Font.ttf(arabic), pw.Font.ttf(hebrew)];
  }

  Future<void> generateMonthlyReport({
    required Profile employee,
    required DateTime month,
    required List<WorkSession> sessions,
  }) async {
    try {
      final fallbackFonts = await _loadFallbackFonts();
      final doc = pw.Document(theme: pw.ThemeData.withFont(fontFallback: fallbackFonts));
      final monthLabel = '${_monthNames[month.month - 1]} ${month.year}';

      final totalDuration = sessions.fold<Duration>(Duration.zero, (sum, session) {
        final endedAt = session.endedAt;
        return endedAt == null ? sum : sum + endedAt.difference(session.startedAt);
      });

      doc.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Text(
              'Work Hours Report',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 12),
            // Three separate Text widgets, not one "Employee: $name (ID:
            // ...)" string - textDirection/shaping is applied per-widget,
            // not per-substring, so putting RTL name content inside one
            // mixed-language Text would reorder the English labels around
            // it too (confirmed: "Employee:" ends up on the wrong side).
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Employee: '),
                _bidiText(employee.fullName),
                pw.Text('  (ID: ${employee.employeeId})'),
              ],
            ),
            pw.Text('Month: $monthLabel'),
            pw.Text('Generated: ${_formatDateTime(DateTime.now())}'),
            pw.SizedBox(height: 20),
            if (sessions.isEmpty)
              pw.Text('No work sessions recorded for this month.')
            else ...[
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Workplace', 'Start', 'End', 'Duration', 'Status'],
                data: [
                  for (final session in sessions)
                    [
                      _formatDate(session.startedAt),
                      session.workplaceLabel,
                      _formatTime(session.startedAt),
                      session.endedAt == null ? '-' : _formatTime(session.endedAt!),
                      session.endedAt == null
                          ? '-'
                          : _formatDuration(session.startedAt, session.endedAt!),
                      session.verificationStatus,
                    ],
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                // fromTextArray renders every cell as plain LTR text by
                // default, with no per-cell way to override that - so an
                // Arabic/Hebrew workplace name (once it had a glyph to draw
                // at all, from the fallback fonts above) still came out
                // wrong. cellBuilder lets us hand back our own widget per
                // cell instead, shaped/directed correctly for what's
                // actually in it - everything else about the cell
                // (padding, alignment, borders) still comes from
                // fromTextArray itself.
                cellBuilder: (index, data, rowNum) => _bidiText(data.toString()),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Total sessions: ${sessions.length}    '
                'Total duration: ${_formatDurationValue(totalDuration)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ],
        ),
      );

      final bytes = await doc.save();
      final fileName = 'work-report-${employee.employeeId}-'
          '${month.year}-${month.month.toString().padLeft(2, '0')}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (_) {
      throw ReportServiceException('Could not generate the report. Please try again.');
    }
  }

  String _formatDate(DateTime dt) {
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$month/$day/${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDateTime(DateTime dt) => '${_formatDate(dt)} ${_formatTime(dt)}';

  String _formatDuration(DateTime start, DateTime end) => _formatDurationValue(end.difference(start));

  String _formatDurationValue(Duration elapsed) {
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes % 60;
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
}
