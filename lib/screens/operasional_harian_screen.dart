import 'package:flutter/material.dart';

import '../app/date_utils.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

class OperasionalHarianScreen extends StatefulWidget {
  const OperasionalHarianScreen({super.key});

  @override
  State<OperasionalHarianScreen> createState() => _OperasionalHarianScreenState();
}

class _OperasionalHarianScreenState extends State<OperasionalHarianScreen> {
  static const green = Color(0xFF176B2C);

  final db = DatabaseHelper.instance;

  DateTime date = DateTime.now();
  List<Pemanen> pemanen = [];
  List<MasterBlok> blok = [];
  List<_BlockAssignment> assignments = [];
  bool loading = true;
  bool saving = false;
  bool hasSavedData = false;
  bool dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);

    final key = dateKey(date);
    final allPemanen = await db.getPemanen();
    final allBlok = await db.getMasterBlok();
    final saved = await db.getPenempatanHarianIds(key);

    final loaded = <_BlockAssignment>[];
    for (final b in allBlok) {
      final id = b.id;
      if (id != null && saved.containsKey(id)) {
        loaded.add(
          _BlockAssignment(
            blokId: id,
            pemanenIds: Set<int>.from(saved[id] ?? const <int>{}),
          ),
        );
      }
    }

    if (loaded.isEmpty) loaded.add(_BlockAssignment());

    if (!mounted) return;
    setState(() {
      pemanen = allPemanen;
      blok = allBlok;
      assignments = loaded;
      hasSavedData = saved.isNotEmpty;
      dirty = false;
      loading = false;
    });
  }

  Future<void> _chooseDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d == null || !mounted) return;

    final sameDate = d.year == date.year &&
        d.month == date.month &&
        d.day == date.day;
    if (sameDate) return;
    if (!await _confirmDiscardChanges() || !mounted) return;

    setState(() => date = d);
    await _load();
  }

  Future<bool> _confirmDiscardChanges() async {
    if (!dirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Perubahan belum disimpan'),
        content: const Text(
          'Ada perubahan pada Absensi Per Blok yang belum disimpan. Abaikan perubahan tersebut?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Tetap di sini'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Abaikan'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _changeBlock(int index, int? value) async {
    final item = assignments[index];
    if (item.blokId == value) return;

    if (item.pemanenIds.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Ganti Blok?'),
          content: const Text(
            'Daftar pemanen pada baris ini akan dikosongkan karena blok berubah.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Ganti'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() {
      item.blokId = value;
      item.pemanenIds.clear();
      dirty = true;
    });
  }

  MasterBlok? _blokById(int? id) {
    if (id == null) return null;
    for (final b in blok) {
      if (b.id == id) return b;
    }
    return null;
  }

  Pemanen? _pemanenById(int id) {
    for (final p in pemanen) {
      if (p.id == id) return p;
    }
    return null;
  }

  Set<int> get _uniquePemanenIds {
    final ids = <int>{};
    for (final item in assignments) {
      if (item.blokId != null) ids.addAll(item.pemanenIds);
    }
    return ids;
  }

  int get _blokCount => assignments.where((a) => a.blokId != null).length;

  List<MasterBlok> _availableBlocksFor(int index) {
    final current = assignments[index].blokId;
    final used = <int>{};
    for (var i = 0; i < assignments.length; i++) {
      if (i == index) continue;
      final id = assignments[i].blokId;
      if (id != null) used.add(id);
    }
    return blok.where((b) => b.id == current || !used.contains(b.id)).toList();
  }

  Future<void> _pickPemanen(int index) async {
    if (assignments[index].blokId == null) {
      _message('Pilih blok terlebih dahulu.');
      return;
    }
    if (pemanen.isEmpty) {
      _message('Master pemanen masih kosong.');
      return;
    }

    final selected = Set<int>.from(assignments[index].pemanenIds);
    final result = await showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              'Pemanen • ${_blokById(assignments[index].blokId)?.kode ?? ''}',
            ),
            contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * .55,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${selected.length} pemanen dipilih',
                      style: const TextStyle(
                        color: green,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: ListView.builder(
                      itemCount: pemanen.length,
                      itemBuilder: (_, i) {
                        final p = pemanen[i];
                        final id = p.id;
                        if (id == null) return const SizedBox.shrink();
                        return CheckboxListTile(
                          dense: true,
                          value: selected.contains(id),
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            '${p.no} • ${p.nama}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selected.add(id);
                              } else {
                                selected.remove(id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selected),
                child: const Text('Pilih'),
              ),
            ],
          ),
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() {
      assignments[index].pemanenIds = result;
      dirty = true;
    });
  }

  void _addBlock() {
    if (assignments.any((a) => a.blokId == null)) {
      _message('Pilih blok pada baris yang masih kosong terlebih dahulu.');
      return;
    }

    final selectedCount = assignments.where((a) => a.blokId != null).length;
    if (selectedCount >= blok.length) {
      _message('Semua blok master sudah digunakan.');
      return;
    }
    setState(() {
      assignments.add(_BlockAssignment());
      dirty = true;
    });
  }

  Future<void> _removeBlock(int index) async {
    final item = assignments[index];
    if (item.blokId != null || item.pemanenIds.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Hapus Blok?'),
          content: const Text(
            'Blok dan daftar pemanen pada baris ini akan dihapus dari perubahan yang sedang dibuat.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Hapus'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    setState(() {
      assignments.removeAt(index);
      if (assignments.isEmpty) assignments.add(_BlockAssignment());
      dirty = true;
    });
  }

  Future<void> _save() async {
    if (saving) return;

    final valid = assignments.where((a) => a.blokId != null).toList();

    // Saat mengedit data yang sudah tersimpan, pengguna boleh menghapus
    // seluruh penempatan untuk tanggal tersebut. Sebelumnya kondisi ini
    // terjebak pada validasi "minimal satu blok" sehingga absensi tidak
    // pernah bisa dikosongkan kembali.
    if (valid.isEmpty) {
      if (!hasSavedData) {
        _message('Pilih minimal satu blok panen.');
        return;
      }

      final clear = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Kosongkan Absensi?'),
          content: Text(
            'Semua penempatan pemanen pada ${displayDate(date)} akan dihapus.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Kosongkan'),
            ),
          ],
        ),
      );
      if (clear != true || !mounted) return;
    }

    final blockIds = valid.map((e) => e.blokId!).toList();
    if (blockIds.toSet().length != blockIds.length) {
      _message('Blok yang sama tidak boleh dibuat lebih dari satu kali.');
      return;
    }

    for (final item in valid) {
      if (item.pemanenIds.isEmpty) {
        final kode = _blokById(item.blokId)?.kode ?? '-';
        _message('Tambahkan minimal satu pemanen pada blok $kode.');
        return;
      }
    }

    final map = <int, Set<int>>{
      for (final item in valid) item.blokId!: Set<int>.from(item.pemanenIds),
    };

    setState(() => saving = true);
    try {
      await db.savePenempatanHarian(
        tanggal: dateKey(date),
        penempatan: map,
      );
      if (!mounted) return;
      _message(
        map.isEmpty
            ? 'Absensi tanggal ini berhasil dikosongkan.'
            : 'Absensi per blok berhasil disimpan.',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      _message('Gagal menyimpan absensi. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmDiscardChanges,
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAF7),
      appBar: AppBar(
        backgroundColor: green,
        foregroundColor: Colors.white,
        title: const Text(
          'Absensi Per Blok',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                InkWell(
                  onTap: _chooseDate,
                  borderRadius: BorderRadius.circular(14),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tanggal',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    child: Text(
                      displayDayDate(date),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5E7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: green),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pilih blok panen, lalu tambahkan pemanen yang bekerja di blok tersebut. Pemanen yang sama boleh dipilih pada lebih dari satu blok.',
                          style: TextStyle(height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: dirty
                        ? const Color(0xFFFFF4E5)
                        : hasSavedData
                            ? const Color(0xFFEAF5E7)
                            : const Color(0xFFF2F4F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        dirty
                            ? Icons.edit_note_rounded
                            : hasSavedData
                                ? Icons.check_circle_outline_rounded
                                : Icons.info_outline_rounded,
                        size: 20,
                        color: dirty
                            ? const Color(0xFF9A6200)
                            : hasSavedData
                                ? green
                                : const Color(0xFF687068),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dirty
                              ? 'Ada perubahan yang belum disimpan'
                              : hasSavedData
                                  ? 'Absensi tanggal ini sudah tersimpan • mode edit'
                                  : 'Belum ada absensi tersimpan untuk tanggal ini',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (blok.isEmpty || pemanen.isEmpty)
                  _MasterWarning(
                    blokEmpty: blok.isEmpty,
                    pemanenEmpty: pemanen.isEmpty,
                  ),
                ...List.generate(assignments.length, (index) {
                  final item = assignments[index];
                  final selectedPeople = item.pemanenIds
                      .map(_pemanenById)
                      .whereType<Pemanen>()
                      .toList()
                    ..sort((a, b) {
                      final an = int.tryParse(a.no);
                      final bn = int.tryParse(b.no);
                      if (an != null && bn != null) return an.compareTo(bn);
                      return a.no.compareTo(b.no);
                    });

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFDDE5DB)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<int>(
                              isExpanded: true,
                              value: item.blokId,
                              decoration: const InputDecoration(
                                labelText: 'Blok Panen',
                                prefixIcon: Icon(Icons.grid_view_outlined),
                              ),
                              items: _availableBlocksFor(index)
                                  .map(
                                    (b) => DropdownMenuItem<int>(
                                      value: b.id,
                                      child: Text(
                                        b.kode,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => _changeBlock(index, value),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Pemanen di blok ini (${selectedPeople.length} orang)',
                                    style: const TextStyle(
                                      color: Color(0xFF687068),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: item.blokId == null
                                      ? null
                                      : () => _pickPemanen(index),
                                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                                  label: const Text('Tambah'),
                                ),
                                if (assignments.length > 1 || item.blokId != null) ...[
                                  const SizedBox(width: 4),
                                  IconButton(
                                    tooltip: 'Hapus blok',
                                    onPressed: () => _removeBlock(index),
                                    icon: const Icon(Icons.delete_outline_rounded),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (selectedPeople.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F8F6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFDDE1DC),
                                  ),
                                ),
                                child: const Text(
                                  'Belum ada pemanen dipilih',
                                  style: TextStyle(color: Color(0xFF7B817B)),
                                ),
                              )
                            else
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: selectedPeople.map((p) {
                                  return InputChip(
                                    avatar: const Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color: green,
                                    ),
                                    label: Text('${p.no} • ${p.nama}'),
                                    onDeleted: p.id == null
                                        ? null
                                        : () {
                                            setState(() {
                                              item.pemanenIds.remove(p.id);
                                              dirty = true;
                                            });
                                          },
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                OutlinedButton.icon(
                  onPressed: blok.isEmpty ? null : _addBlock,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('TAMBAH BLOK'),
                ),
                const SizedBox(height: 14),
                _SummaryCard(
                  pemanenCount: _uniquePemanenIds.length,
                  blokCount: _blokCount,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: saving ? null : _save,
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      saving
                          ? 'MENYIMPAN...'
                          : hasSavedData
                              ? 'SIMPAN PERUBAHAN'
                              : 'SIMPAN ABSENSI PER BLOK',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Dropdown Pemanen pada Data Hitung, Info Pemanen, dan Data Truk akan mengikuti blok yang dipilih untuk tanggal yang sama.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF687068),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

class _BlockAssignment {
  int? blokId;
  Set<int> pemanenIds;

  _BlockAssignment({this.blokId, Set<int>? pemanenIds})
      : pemanenIds = pemanenIds ?? <int>{};
}

class _MasterWarning extends StatelessWidget {
  final bool blokEmpty;
  final bool pemanenEmpty;

  const _MasterWarning({required this.blokEmpty, required this.pemanenEmpty});

  @override
  Widget build(BuildContext context) {
    final missing = <String>[
      if (blokEmpty) 'Master Blok',
      if (pemanenEmpty) 'Master Pemanen',
    ].join(' dan ');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$missing masih kosong. Isi master data terlebih dahulu.'),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int pemanenCount;
  final int blokCount;

  const _SummaryCard({required this.pemanenCount, required this.blokCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFEAF5E7),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: _Metric(
                icon: Icons.groups_rounded,
                value: '$pemanenCount',
                label: 'Pemanen Hadir',
              ),
            ),
            const SizedBox(
              height: 42,
              child: VerticalDivider(color: Color(0xFFC9DEC6)),
            ),
            Expanded(
              child: _Metric(
                icon: Icons.location_on_rounded,
                value: '$blokCount',
                label: 'Blok Panen',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _Metric({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: _OperasionalHarianScreenState.green),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            Text(label, style: const TextStyle(fontSize: 11.5)),
          ],
        ),
      ],
    );
  }
}
