import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';
import '../models/models.dart';

class MasterTrukScreen extends StatefulWidget {
  const MasterTrukScreen({super.key});

  @override
  State<MasterTrukScreen> createState() => _MasterTrukScreenState();
}

class _MasterTrukScreenState extends State<MasterTrukScreen> {
  static const green = Color(0xFF176B2C);
  static const darkGreen = Color(0xFF0C5E2B);
  static const page = Color(0xFFF7F9F6);

  final searchC = TextEditingController();
  List<MasterTruk> items = [];
  String filter = 'SEMUA';
  bool loading = true;
  bool importing = false;

  @override
  void initState() {
    super.initState();
    searchC.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    searchC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    final d = await DatabaseHelper.instance.getMasterTruk();
    if (!mounted) return;
    setState(() {
      items = d;
      loading = false;
    });
  }

  List<MasterTruk> get visibleItems {
    final q = searchC.text.trim().toLowerCase();
    return items.where((item) {
      if (filter != 'SEMUA' && item.jenis != filter) return false;
      if (q.isEmpty) return true;
      return item.nama.toLowerCase().contains(q) ||
          item.jenis.toLowerCase().contains(q) ||
          (item.noPolisi ?? '').toLowerCase().contains(q) ||
          item.namaSopirOperator.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _form({MasterTruk? current}) async {
    var jenis = current?.jenis ?? 'TRUK';
    final kodeC = TextEditingController(text: current?.nama ?? '');
    final polisiC = TextEditingController(text: current?.noPolisi ?? '');
    final orangC = TextEditingController(text: current?.namaSopirOperator ?? '');

    final result = await showDialog<MasterTruk>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isTruk = jenis == 'TRUK';
            return AlertDialog(
              title: Text(current == null ? 'Tambah Angkutan' : 'Edit Angkutan'),
              contentPadding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 430,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Jenis Angkutan',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'TRUK',
                            icon: Icon(Icons.local_shipping_rounded),
                            label: Text('TRUK'),
                          ),
                          ButtonSegment(
                            value: 'LD',
                            icon: Icon(Icons.agriculture_rounded),
                            label: Text('LD / Jonder'),
                          ),
                        ],
                        selected: {jenis},
                        onSelectionChanged: (value) {
                          setDialogState(() {
                            jenis = value.first;
                            if (jenis == 'LD') polisiC.clear();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: kodeC,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: isTruk ? 'Kode Truk' : 'Kode LD',
                          prefixIcon: Icon(
                            isTruk
                                ? Icons.local_shipping_rounded
                                : Icons.agriculture_rounded,
                          ),
                          hintText: isTruk ? 'TRK-01' : 'LD-01',
                        ),
                      ),
                      if (isTruk) ...[
                        const SizedBox(height: 12),
                        TextField(
                          controller: polisiC,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'No Polisi',
                            prefixIcon: Icon(Icons.directions_car_rounded),
                            hintText: 'BK 9123 AB',
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: orangC,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: isTruk ? 'Nama Sopir' : 'Nama Operator',
                          prefixIcon: const Icon(Icons.person_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    final kode = kodeC.text.trim().toUpperCase();
                    final polisi = polisiC.text.trim().toUpperCase();
                    final orang = orangC.text.trim();
                    if (kode.isEmpty || orang.isEmpty || (isTruk && polisi.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lengkapi data wajib terlebih dahulu.')),
                      );
                      return;
                    }
                    Navigator.pop(
                      dialogContext,
                      MasterTruk(
                        id: current?.id,
                        nama: kode,
                        jenis: jenis,
                        noPolisi: isTruk ? polisi : null,
                        namaSopirOperator: orang,
                      ),
                    );
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    kodeC.dispose();
    polisiC.dispose();
    orangC.dispose();
    if (result == null) return;

    try {
      if (current == null) {
        await DatabaseHelper.instance.addMasterTruk(result);
      } else {
        await DatabaseHelper.instance.updateMasterTruk(result);
      }
      await _load();
      if (mounted) _message('Master angkutan berhasil disimpan.');
    } catch (_) {
      if (mounted) _message('Kode angkutan sudah digunakan.');
    }
  }

  Future<void> _delete(MasterTruk item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Master Angkutan?'),
        content: Text('${item.nama} • ${item.jenis}\n${item.detailSingkat}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true && item.id != null) {
      await DatabaseHelper.instance.deleteMasterTruk(item.id!);
      await _load();
    }
  }

  String _cellText(dynamic cell) {
    final dynamic value = cell?.value;
    if (value == null) return '';
    try {
      return value.value?.toString().trim() ?? '';
    } catch (_) {
      return value.toString().trim();
    }
  }

  String _normalizeHeader(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(' ', '_')
      .replaceAll('-', '_');

  Future<void> _importExcel() async {
    if (importing) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => importing = true);
    try {
      final picked = result.files.single;
      var bytes = picked.bytes;
      if (bytes == null && picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      }
      if (bytes == null) throw Exception('File tidak dapat dibaca.');

      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) throw Exception('Workbook tidak memiliki sheet.');
      final table = excel.tables.values.first;
      if (table.rows.isEmpty) throw Exception('File Excel kosong.');

      final headers = <String, int>{};
      for (var i = 0; i < table.rows.first.length; i++) {
        final h = _normalizeHeader(_cellText(table.rows.first[i]));
        if (h.isNotEmpty) headers[h] = i;
      }

      const required = ['jenis', 'kode', 'no_polisi', 'nama_sopir_operator'];
      final missing = required.where((h) => !headers.containsKey(h)).toList();
      if (missing.isNotEmpty) {
        throw Exception('Kolom tidak lengkap: ${missing.join(', ')}');
      }

      final parsed = <MasterTruk>[];
      final errors = <String>[];
      final seen = <String>{};

      for (var r = 1; r < table.rows.length; r++) {
        final row = table.rows[r];
        String get(String key) {
          final idx = headers[key]!;
          return idx < row.length ? _cellText(row[idx]) : '';
        }

        final jenis = get('jenis').toUpperCase();
        final kode = get('kode').toUpperCase();
        final polisi = get('no_polisi').toUpperCase();
        final orang = get('nama_sopir_operator');

        if ([jenis, kode, polisi, orang].every((e) => e.trim().isEmpty)) continue;
        final rowNo = r + 1;
        if (jenis != 'TRUK' && jenis != 'LD') {
          errors.add('Baris $rowNo: jenis harus TRUK atau LD.');
          continue;
        }
        if (kode.isEmpty) {
          errors.add('Baris $rowNo: kode wajib diisi.');
          continue;
        }
        if (orang.isEmpty) {
          errors.add('Baris $rowNo: nama sopir/operator wajib diisi.');
          continue;
        }
        if (jenis == 'TRUK' && polisi.isEmpty) {
          errors.add('Baris $rowNo: no_polisi wajib untuk TRUK.');
          continue;
        }
        if (!seen.add(kode)) {
          errors.add('Baris $rowNo: kode $kode duplikat dalam file.');
          continue;
        }
        parsed.add(
          MasterTruk(
            nama: kode,
            jenis: jenis,
            noPolisi: jenis == 'TRUK' ? polisi : null,
            namaSopirOperator: orang,
          ),
        );
      }

      if (errors.isNotEmpty) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Import belum dapat dilanjutkan'),
            content: SizedBox(
              width: 430,
              child: SingleChildScrollView(
                child: Text(errors.take(12).join('\n')),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tutup')),
            ],
          ),
        );
        return;
      }
      if (parsed.isEmpty) throw Exception('Tidak ada data yang dapat diimport.');
      if (!mounted) return;

      final mode = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Konfirmasi Import'),
          content: Text(
            '${parsed.length} data valid ditemukan.\n\n'
            'Gabungkan: tambah/perbarui berdasarkan kode.\n'
            'Ganti Semua: hapus seluruh Master Angkutan lalu isi dari file.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
            OutlinedButton(
              onPressed: () => Navigator.pop(c, 'merge'),
              child: const Text('Gabungkan'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, 'replace'),
              child: const Text('Ganti Semua'),
            ),
          ],
        ),
      );
      if (mode == null) return;

      await DatabaseHelper.instance.importMasterTruk(
        parsed,
        replaceAll: mode == 'replace',
      );
      await _load();
      if (mounted) _message('${parsed.length} data berhasil diimport.');
    } catch (e) {
      if (mounted) _message('Import gagal: $e');
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  Future<void> _shareTemplate() async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Master Angkutan'];
      excel.delete('Sheet1');
      excel.setDefaultSheet('Master Angkutan');

      sheet.appendRow([
        TextCellValue('jenis'),
        TextCellValue('kode'),
        TextCellValue('no_polisi'),
        TextCellValue('nama_sopir_operator'),
      ]);
      sheet.appendRow([
        TextCellValue('TRUK'),
        TextCellValue('TRK-01'),
        TextCellValue('BK 9123 AB'),
        TextCellValue('Andi Pratama'),
      ]);
      sheet.appendRow([
        TextCellValue('LD'),
        TextCellValue('LD-01'),
        TextCellValue(''),
        TextCellValue('Eko Setiawan'),
      ]);

      final petunjuk = excel['Petunjuk'];
      petunjuk.appendRow([TextCellValue('FORMAT IMPORT MASTER ANGKUTAN')]);
      petunjuk.appendRow([TextCellValue('jenis'), TextCellValue('TRUK atau LD (huruf kapital).')]);
      petunjuk.appendRow([TextCellValue('kode'), TextCellValue('Kode unik angkutan, contoh TRK-01 atau LD-01.')]);
      petunjuk.appendRow([TextCellValue('no_polisi'), TextCellValue('Wajib untuk TRUK, kosongkan untuk LD.')]);
      petunjuk.appendRow([TextCellValue('nama_sopir_operator'), TextCellValue('Nama sopir untuk TRUK atau nama operator untuk LD.')]);
      petunjuk.appendRow([TextCellValue('Catatan'), TextCellValue('Jangan mengubah nama header pada baris pertama.')]);

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Gagal membuat template.');
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'format_import_master_angkutan.xlsx'));
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [
          XFile(
            file.path,
            name: p.basename(file.path),
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: 'Template Import Master Angkutan KeraniSawit',
      );
    } catch (e) {
      if (mounted) _message('Gagal membuat template: $e');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final list = visibleItems;
    final trukCount = items.where((e) => e.isTruk).length;
    final ldCount = items.where((e) => e.isLd).length;

    return Scaffold(
      backgroundColor: page,
      appBar: AppBar(
        title: const Text('Master Angkutan', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Template Excel',
            onPressed: _shareTemplate,
            icon: const Icon(Icons.download_rounded),
          ),
          IconButton(
            tooltip: 'Import Excel',
            onPressed: importing ? null : _importExcel,
            icon: importing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _form(),
        backgroundColor: green,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_rounded),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: green,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 96),
                children: [
                  TextField(
                    controller: searchC,
                    decoration: InputDecoration(
                      hintText: 'Cari kode, no polisi, sopir atau operator...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: searchC.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: searchC.clear,
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      _FilterChip(
                        label: 'Semua ${items.length}',
                        selected: filter == 'SEMUA',
                        onTap: () => setState(() => filter = 'SEMUA'),
                      ),
                      _FilterChip(
                        label: 'Truk $trukCount',
                        selected: filter == 'TRUK',
                        onTap: () => setState(() => filter = 'TRUK'),
                      ),
                      _FilterChip(
                        label: 'LD $ldCount',
                        selected: filter == 'LD',
                        onTap: () => setState(() => filter = 'LD'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (list.isEmpty)
                    const _EmptyMasterCard()
                  else
                    ...list.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _MasterAngkutanCard(
                          item: item,
                          onEdit: () => _form(current: item),
                          onDelete: () => _delete(item),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: const Color(0xFFDDF1E2),
      side: BorderSide(color: selected ? const Color(0xFF87B994) : const Color(0xFFE0E6E0)),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF0C5E2B) : const Color(0xFF657067),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MasterAngkutanCard extends StatelessWidget {
  final MasterTruk item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MasterAngkutanCard({required this.item, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isTruk = item.isTruk;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1E7E1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6EC),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isTruk ? Icons.local_shipping_rounded : Icons.agriculture_rounded,
            color: const Color(0xFF176B2C),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                item.nama,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F3F0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.jenis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            item.detailSingkat.isEmpty ? '-' : item.detailSingkat,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF697269), fontSize: 12),
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Hapus')),
          ],
        ),
      ),
    );
  }
}

class _EmptyMasterCard extends StatelessWidget {
  const _EmptyMasterCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1E7E1)),
      ),
      child: const Column(
        children: [
          Icon(Icons.local_shipping_outlined, size: 38, color: Color(0xFF8A958B)),
          SizedBox(height: 10),
          Text('Belum ada Master Angkutan', style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text(
            'Tambahkan manual atau import dari template Excel.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF737D75)),
          ),
        ],
      ),
    );
  }
}
