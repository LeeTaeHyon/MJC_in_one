import "package:excel/excel.dart" as xls;
import "package:mio_notice/features/timetable/models/timetable_models.dart";
import "package:mio_notice/features/timetable/services/timetable_slot_parser.dart";

/// Reads MJC-style «전체 강의시간표» xlsx: header row with [과목명] and [시간표].
abstract final class TimetableExcelParser {
  static String _cellToString(xls.Data? cell) {
    if (cell?.value == null) return "";
    final xls.CellValue v = cell!.value!;
    if (v is xls.TextCellValue) {
      // package:excel defines its own [TextSpan] whose [toString] flattens text.
      return v.value.toString().trim();
    }
    if (v is xls.IntCellValue) return v.value.toString();
    if (v is xls.DoubleCellValue) {
      final double d = v.value;
      if (d == d.roundToDouble()) return d.round().toString();
      return d.toString();
    }
    return v.toString().trim();
  }

  static bool _rowLooksLikeHeader(List<xls.Data?> row) {
    final List<String> cells =
        row.map(_cellToString).where((String s) => s.isNotEmpty).toList();
    if (cells.length < 5) return false;
    final String joined = cells.join("\u0001");
    return joined.contains("과목명") && joined.contains("시간표");
  }

  static int? _columnIndexForHeader(List<xls.Data?> headerRow, String keyword) {
    for (int c = 0; c < headerRow.length; c++) {
      if (_cellToString(headerRow[c]).trim() == keyword) return c;
    }
    for (int c = 0; c < headerRow.length; c++) {
      if (_cellToString(headerRow[c]).contains(keyword)) return c;
    }
    return null;
  }

  /// Decodes first sheet of [bytes] into offerings. Throws if no table or header.
  static List<ParsedCourseOffering> parseBytes(List<int> bytes) {
    final xls.Excel excel = xls.Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw const TimetableExcelParseException("시트가 없습니다.");
    }
    final String firstKey = excel.tables.keys.first;
    final xls.Sheet sheet = excel.tables[firstKey]!;

    int headerRowIndex = -1;
    final int maxScan = sheet.maxRows < 120 ? sheet.maxRows : 120;
    for (int r = 0; r < maxScan; r++) {
      final List<xls.Data?> row = sheet.row(r);
      if (_rowLooksLikeHeader(row)) {
        headerRowIndex = r;
        break;
      }
    }
    if (headerRowIndex < 0) {
      throw const TimetableExcelParseException("표 헤더(과목명·시간표)를 찾지 못했습니다.");
    }

    final List<xls.Data?> headerRow = sheet.row(headerRowIndex);
    final int? colCourse = _columnIndexForHeader(headerRow, "과목명");
    final int? colTime = _columnIndexForHeader(headerRow, "시간표");
    if (colCourse == null || colTime == null) {
      throw const TimetableExcelParseException("필수 열(과목명·시간표)을 찾지 못했습니다.");
    }
    final int? colDept = _columnIndexForHeader(headerRow, "학과명");
    final int? colSection = _columnIndexForHeader(headerRow, "분반");
    final int? colProf = _columnIndexForHeader(headerRow, "교수명");
    final int? colGrade = _columnIndexForHeader(headerRow, "학년");
    final int? colCompletion = _columnIndexForHeader(headerRow, "이수구분명");
    final int? colCredits = _columnIndexForHeader(headerRow, "학점");
    final int? colCategory = _columnIndexForHeader(headerRow, "과정구분");

    String lastCategory = "";
    String lastDept = "";

    final List<ParsedCourseOffering> out = <ParsedCourseOffering>[];

    for (int r = headerRowIndex + 1; r < sheet.maxRows; r++) {
      final List<xls.Data?> row = sheet.row(r);
      String cellAt(int? idx) {
        if (idx == null || idx >= row.length) return "";
        return _cellToString(row[idx]);
      }

      String cat = cellAt(colCategory);
      if (cat.isEmpty) {
        cat = lastCategory;
      } else {
        lastCategory = cat;
      }

      String dept = cellAt(colDept);
      if (dept.isEmpty) {
        dept = lastDept;
      } else {
        lastDept = dept;
      }

      final String courseName = cellAt(colCourse).trim();
      final String timetableRaw = cellAt(colTime).trim();
      if (courseName.isEmpty && timetableRaw.isEmpty) continue;

      final String section = cellAt(colSection).trim();
      final String professor = cellAt(colProf).trim();
      final String offeringId = TimetableSlotParser.stableOfferingId(
        department: dept,
        courseName: courseName,
        section: section,
        professor: professor,
      );

      final String colorKey = "$courseName|$section";
      final List<TimetableSlot> slots = TimetableSlotParser.parseTimetableCell(
        raw: timetableRaw,
        courseName: courseName,
        offeringId: offeringId,
        colorKey: colorKey,
      );

      if (courseName.isEmpty || slots.isEmpty) continue;

      out.add(
        ParsedCourseOffering(
          offeringId: offeringId,
          courseCategory: cat,
          department: dept,
          courseName: courseName,
          section: section,
          professor: professor,
          gradeYear: cellAt(colGrade).trim(),
          completionType: cellAt(colCompletion).trim(),
          credits: cellAt(colCredits).trim(),
          slots: slots,
          rawTimetableText: timetableRaw,
        ),
      );
    }

    if (out.isEmpty) {
      throw const TimetableExcelParseException("유효한 강의 행이 없습니다. 시간표 열 형식을 확인해 주세요.");
    }
    return out;
  }
}

class TimetableExcelParseException implements Exception {
  const TimetableExcelParseException(this.message);
  final String message;

  @override
  String toString() => message;
}
