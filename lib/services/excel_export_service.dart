import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app/date_utils.dart';
import '../models/models.dart';

class ExcelExportService {
  const ExcelExportService._();

  static Future<File> exportDataHitung({
    required DateTime startDate,
    required DateTime endDate,
    required List<DataHitung> rows,
  }) async {
    final excel = Excel.createExcel();

    final rekapSheet = excel['Rekap'];
    final detailSheet = excel['Detail'];
    excel.delete('Sheet1');
    excel.setDefaultSheet('Rekap');

    _buildRekapSheet(
      rekapSheet,
      startDate: startDate,
      endDate: endDate,
      rows: rows,
    );

    _buildDetailSheet(
      detailSheet,
      rows: rows,
    );

    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Gagal membuat file Excel.');
    }

    final directory = await getTemporaryDirectory();
    final fileName =
        'KeraniSawit_DataHitung_${dateKey(startDate)}_sampai_${dateKey(endDate)}.xlsx';

    final file = File(p.join(directory.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    return file;
  }

  static Future<void> shareExcel(File file) async {
    await Share.shareXFiles(
      [
        XFile(
          file.path,
          name: p.basename(file.path),
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      subject: 'Rekap Data Hitung Kerani Sawit',
      text: 'File Excel Data Hitung Kerani Sawit.',
    );
  }

  static void _buildRekapSheet(
    Sheet sheet, {
    required DateTime startDate,
    required DateTime endDate,
    required List<DataHitung> rows,
  }) {
    sheet.appendRow([
      TextCellValue('KERANI SAWIT - REKAP DATA HITUNG'),
    ]);

    sheet.appendRow([
      TextCellValue('Periode'),
      TextCellValue(
        '${displayDate(startDate)} s.d. ${displayDate(endDate)}',
      ),
    ]);

    sheet.appendRow([
      TextCellValue('Total Input'),
      IntCellValue(rows.length),
      TextCellValue('Total Janjang'),
      IntCellValue(
        rows.fold<int>(0, (total, item) => total + item.janjang),
      ),
      TextCellValue('Pemanen'),
      IntCellValue(
        rows.map((item) => item.noPemanen).toSet().length,
      ),
    ]);

    sheet.appendRow(<CellValue>[]);

    sheet.appendRow([
      TextCellValue('Tanggal'),
      TextCellValue('No Pemanen'),
      TextCellValue('Nama Pemanen'),
      TextCellValue('Jumlah Input'),
      TextCellValue('Total Janjang'),
    ]);

    final grouped = <String, Map<String, _RekapExportRow>>{};

    for (final item in rows) {
      final perTanggal = grouped.putIfAbsent(
        item.tanggal,
        () => <String, _RekapExportRow>{},
      );

      final current = perTanggal[item.noPemanen];

      if (current == null) {
        perTanggal[item.noPemanen] = _RekapExportRow(
          nama: item.namaPemanen,
          inputCount: 1,
          totalJanjang: item.janjang,
        );
      } else {
        current.inputCount += 1;
        current.totalJanjang += item.janjang;
      }
    }

    final tanggalKeys = grouped.keys.toList()..sort();

    for (final tanggal in tanggalKeys) {
      final perPemanen = grouped[tanggal]!;
      final pemanenKeys = perPemanen.keys.toList()
        ..sort((a, b) {
          final ai = int.tryParse(a);
          final bi = int.tryParse(b);
          if (ai != null && bi != null) {
            return ai.compareTo(bi);
          }
          return a.compareTo(b);
        });

      for (final no in pemanenKeys) {
        final item = perPemanen[no]!;
        sheet.appendRow([
          TextCellValue(tanggal),
          TextCellValue(no),
          TextCellValue(item.nama),
          IntCellValue(item.inputCount),
          IntCellValue(item.totalJanjang),
        ]);
      }
    }

    sheet.setColumnWidth(0, 15);
    sheet.setColumnWidth(1, 13);
    sheet.setColumnWidth(2, 24);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 16);
  }

  static void _buildDetailSheet(
    Sheet sheet, {
    required List<DataHitung> rows,
  }) {
    sheet.appendRow([
      TextCellValue('Tanggal'),
      TextCellValue('Jam'),
      TextCellValue('No Pemanen'),
      TextCellValue('Nama Pemanen'),
      TextCellValue('Janjang'),
    ]);

    for (final item in rows) {
      sheet.appendRow([
        TextCellValue(item.tanggal),
        TextCellValue(item.jamInput),
        TextCellValue(item.noPemanen),
        TextCellValue(item.namaPemanen),
        IntCellValue(item.janjang),
      ]);
    }

    sheet.setColumnWidth(0, 15);
    sheet.setColumnWidth(1, 10);
    sheet.setColumnWidth(2, 13);
    sheet.setColumnWidth(3, 24);
    sheet.setColumnWidth(4, 12);
  }
}

class _RekapExportRow {
  final String nama;
  int inputCount;
  int totalJanjang;

  _RekapExportRow({
    required this.nama,
    required this.inputCount,
    required this.totalJanjang,
  });
}
