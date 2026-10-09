import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  static const darkGreen = Color(0xFF0C5E2B);
  static const ink = Color(0xFF172119);
  static const muted = Color(0xFF687068);
  static const page = Color(0xFFF8FAF7);
  static const line = Color(0xFFDDE5DB);

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

    final sameDate =
        d.year == date.year && d.month == date.month && d.day == date.day;
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
    } catch (_) {
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
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 390;
    final horizontal = compact ? 14.0 : 16.0;

    return WillPopScope(
      onWillPop: _confirmDiscardChanges,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: page,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: page,
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _AbsensiHeader(
                        compact: compact,
                        onBack: () async {
                          if (await _confirmDiscardChanges() && mounted) {
                            Navigator.maybePop(context);
                          }
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontal,
                          10,
                          horizontal,
                          28,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DateCard(
                              compact: compact,
                              date: date,
                              onTap: _chooseDate,
                            ),
                            const SizedBox(height: 12),
                            const _InstructionCard(),
                            const SizedBox(height: 10),
                            _StatusCard(
                              dirty: dirty,
                              hasSavedData: hasSavedData,
                            ),
                            if (blok.isEmpty || pemanen.isEmpty) ...[
                              const SizedBox(height: 10),
                              _MasterWarning(
                                blokEmpty: blok.isEmpty,
                                pemanenEmpty: pemanen.isEmpty,
                              ),
                            ],
                            const SizedBox(height: 12),
                            ...List.generate(assignments.length, (index) {
                              final item = assignments[index];
                              final selectedPeople = item.pemanenIds
                                  .map(_pemanenById)
                                  .whereType<Pemanen>()
                                  .toList()
                                ..sort((a, b) {
                                  final an = int.tryParse(a.no);
                                  final bn = int.tryParse(b.no);
                                  if (an != null && bn != null) {
                                    return an.compareTo(bn);
                                  }
                                  return a.no.compareTo(b.no);
                                });

                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == assignments.length - 1
                                      ? 0
                                      : 10,
                                ),
                                child: _BlockAssignmentCard(
                                  compact: compact,
                                  index: index,
                                  item: item,
                                  availableBlocks:
                                      _availableBlocksFor(index),
                                  selectedPeople: selectedPeople,
                                  showDelete:
                                      assignments.length > 1 ||
                                          item.blokId != null,
                                  onChanged: (value) =>
                                      _changeBlock(index, value),
                                  onAddPemanen: item.blokId == null
                                      ? null
                                      : () => _pickPemanen(index),
                                  onRemoveBlock: () => _removeBlock(index),
                                  onRemovePemanen: (id) {
                                    setState(() {
                                      item.pemanenIds.remove(id);
                                      dirty = true;
                                    });
                                  },
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: blok.isEmpty ? null : _addBlock,
                                icon: const Icon(Icons.add_rounded, size: 22),
                                label: const Text(
                                  'TAMBAH BLOK',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .2,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: green,
                                  side: const BorderSide(
                                    color: Color(0xFF8DC9A2),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _SummaryCard(
                              pemanenCount: _uniquePemanenIds.length,
                              blokCount: _blokCount,
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: saving ? null : _save,
                                icon: saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  saving
                                      ? 'MENYIMPAN...'
                                      : hasSavedData
                                          ? 'SIMPAN PERUBAHAN'
                                          : 'SIMPAN ABSENSI PER BLOK',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .1,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0C7137),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Dropdown Pemanen pada Data Hitung, Info Pemanen, dan Data Truk akan mengikuti blok yang dipilih untuk tanggal yang sama.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: muted,
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AbsensiHeader extends StatelessWidget {
  final bool compact;
  final VoidCallback onBack;

  const _AbsensiHeader({
    required this.compact,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final topInset = MediaQuery.paddingOf(context).top;
    final visualHeight = (width * 0.29).clamp(106.0, 142.0);
    final totalHeight = topInset + visualHeight;

    return SizedBox(
      height: totalHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/headers/absen.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFF075D2E).withValues(alpha: .80),
                  const Color(0xFF075D2E).withValues(alpha: .38),
                  Colors.transparent,
                ],
                stops: const [0, .44, .82],
              ),
            ),
          ),
          Positioned(
            left: compact ? 16 : 18,
            top: topInset + 16,
            child: Material(
              color: Colors.white.withValues(alpha: .15),
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: compact ? 38 : 40,
                  height: compact ? 38 : 40,
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: compact ? 68 : 74,
            right: 20,
            top: topInset + 20,
            child: Text(
              'Absensi Per Blok',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 22 : 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  final bool compact;
  final DateTime date;
  final VoidCallback onTap;

  const _DateCard({
    required this.compact,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE0E6DF)),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 38 : 40,
                height: compact ? 38 : 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF6EC),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  color: _OperasionalHarianScreenState.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tanggal',
                      style: TextStyle(
                        color: _OperasionalHarianScreenState.muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayDayDate(date),
                      style: TextStyle(
                        color: _OperasionalHarianScreenState.ink,
                        fontSize: compact ? 14.2 : 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.calendar_today_outlined,
                color: Color(0xFF596159),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  const _InstructionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5E7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: _OperasionalHarianScreenState.green,
            size: 24,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pilih blok panen, lalu tambahkan pemanen yang bekerja di blok tersebut. Pemanen yang sama boleh dipilih pada lebih dari satu blok.',
              style: TextStyle(
                color: Color(0xFF2B332D),
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool dirty;
  final bool hasSavedData;

  const _StatusCard({
    required this.dirty,
    required this.hasSavedData,
  });

  @override
  Widget build(BuildContext context) {
    final bg = dirty
        ? const Color(0xFFFFF4E5)
        : hasSavedData
            ? const Color(0xFFEAF5E7)
            : const Color(0xFFF2F4F1);
    final icon = dirty
        ? Icons.edit_note_rounded
        : hasSavedData
            ? Icons.check_circle_outline_rounded
            : Icons.info_outline_rounded;
    final color = dirty
        ? const Color(0xFF9A6200)
        : hasSavedData
            ? _OperasionalHarianScreenState.green
            : const Color(0xFF687068);
    final text = dirty
        ? 'Ada perubahan yang belum disimpan'
        : hasSavedData
            ? 'Absensi tanggal ini sudah tersimpan • mode edit'
            : 'Belum ada absensi tersimpan untuk tanggal ini';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockAssignmentCard extends StatelessWidget {
  final bool compact;
  final int index;
  final _BlockAssignment item;
  final List<MasterBlok> availableBlocks;
  final List<Pemanen> selectedPeople;
  final bool showDelete;
  final ValueChanged<int?> onChanged;
  final VoidCallback? onAddPemanen;
  final VoidCallback onRemoveBlock;
  final ValueChanged<int> onRemovePemanen;

  const _BlockAssignmentCard({
    required this.compact,
    required this.index,
    required this.item,
    required this.availableBlocks,
    required this.selectedPeople,
    required this.showDelete,
    required this.onChanged,
    required this.onAddPemanen,
    required this.onRemoveBlock,
    required this.onRemovePemanen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _OperasionalHarianScreenState.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .025),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int>(
            isExpanded: true,
            value: item.blokId,
            decoration: InputDecoration(
              labelText: 'Blok Panen',
              prefixIcon: const Icon(Icons.grid_view_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFDDE5DB)),
              ),
            ),
            items: availableBlocks
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
            onChanged: onChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pemanen di blok ini (${selectedPeople.length} orang)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _OperasionalHarianScreenState.darkGreen,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onAddPemanen,
                icon: const Icon(
                  Icons.person_add_alt_1_rounded,
                  size: 17,
                ),
                label: const Text('Tambah'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _OperasionalHarianScreenState.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (showDelete) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Hapus blok',
                  onPressed: onRemoveBlock,
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
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAF8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFDDE1DC),
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.groups_rounded,
                    color: Color(0xFF9AA29B),
                    size: 28,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Belum ada pemanen dipilih',
                    style: TextStyle(
                      color: Color(0xFF626B64),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Pilih blok terlebih dahulu, lalu tambahkan pemanen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF8A918B),
                      fontSize: 11,
                    ),
                  ),
                ],
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
                    color: _OperasionalHarianScreenState.green,
                  ),
                  label: Text('${p.no} • ${p.nama}'),
                  onDeleted:
                      p.id == null ? null : () => onRemovePemanen(p.id!),
                );
              }).toList(),
            ),
        ],
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

  const _MasterWarning({
    required this.blokEmpty,
    required this.pemanenEmpty,
  });

  @override
  Widget build(BuildContext context) {
    final missing = <String>[
      if (blokEmpty) 'Master Blok',
      if (pemanenEmpty) 'Master Pemanen',
    ].join(' dan ');

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1E0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFD98200),
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: Color(0xFF5F3D12),
                  fontSize: 12.2,
                  height: 1.3,
                ),
                children: [
                  TextSpan(
                    text: '$missing masih kosong.\n',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const TextSpan(text: 'Isi master data terlebih dahulu.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int pemanenCount;
  final int blokCount;

  const _SummaryCard({
    required this.pemanenCount,
    required this.blokCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5E7),
        borderRadius: BorderRadius.circular(8),
      ),
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
    );
  }
}

class _Metric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _Metric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFD9EFDB),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: _OperasionalHarianScreenState.green,
          ),
        ),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 19,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: _OperasionalHarianScreenState.muted,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
