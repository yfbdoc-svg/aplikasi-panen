import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../database/database_helper.dart';
import '../models/models.dart';

class MasterBlokScreen extends StatefulWidget {
  const MasterBlokScreen({super.key});

  @override
  State<MasterBlokScreen> createState() => _MasterBlokScreenState();
}

class _MasterBlokScreenState extends State<MasterBlokScreen> {
  static const green = Color(0xFF176B2C);
  static const muted = Color(0xFF6F7972);

  final searchC = TextEditingController();
  List<MasterBlok> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    searchC.addListener(_refreshView);
  }

  @override
  void dispose() {
    searchC.removeListener(_refreshView);
    searchC.dispose();
    super.dispose();
  }

  void _refreshView() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    final data = await DatabaseHelper.instance.getMasterBlok();
    if (!mounted) return;
    setState(() {
      items = data;
      loading = false;
    });
  }

  List<MasterBlok> get filteredItems {
    final q = searchC.text.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((b) {
      final tt = b.tahunTanam?.toString() ?? '';
      final bjr = b.bjr.toStringAsFixed(2).replaceAll('.', ',');
      final luas = b.luasHa?.toStringAsFixed(2).replaceAll('.', ',') ?? '';
      return b.kode.toLowerCase().contains(q) ||
          tt.contains(q) ||
          bjr.contains(q) ||
          luas.contains(q);
    }).toList();
  }

  String _bjrText(double value) {
    if (value <= 0) return 'BJR belum diisi';
    return 'BJR ${value.toStringAsFixed(2).replaceAll('.', ',')} kg/jjg';
  }

  String _ttText(int? value) => value == null ? 'TT belum diisi' : 'TT $value';

  String _luasText(double? value) => value == null || value <= 0
      ? 'Luas belum diisi'
      : '${value.toStringAsFixed(2).replaceAll('.', ',')} Ha';

  Future<void> _form({MasterBlok? current}) async {
    final kodeC = TextEditingController(text: current?.kode ?? '');
    final bjrC = TextEditingController(
      text: current == null || current.bjr <= 0
          ? ''
          : current.bjr.toStringAsFixed(2).replaceAll('.', ','),
    );
    final tahunC = TextEditingController(
      text: current?.tahunTanam?.toString() ?? '',
    );
    final luasC = TextEditingController(
      text: current?.luasHa == null
          ? ''
          : current!.luasHa!.toStringAsFixed(2).replaceAll('.', ','),
    );
    String? error;

    final result = await showDialog<MasterBlok>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              title: Text(current == null ? 'Tambah Blok' : 'Edit Blok'),
              contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: kodeC,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Kode Blok',
                          prefixIcon: const Icon(Icons.grid_view_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: bjrC,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9,.]'),
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: 'BJR',
                          hintText: 'Contoh 18,50',
                          prefixIcon: const Icon(Icons.scale_rounded),
                          suffixText: 'kg/jjg',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: tahunC,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 4,
                        decoration: InputDecoration(
                          labelText: 'Tahun Tanam',
                          hintText: 'Contoh 2013',
                          counterText: '',
                          prefixIcon: const Icon(Icons.calendar_month_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: luasC,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                        ],
                        decoration: InputDecoration(
                          labelText: 'Luas Blok (Opsional)',
                          hintText: 'Contoh 25,60',
                          prefixIcon: const Icon(Icons.map_outlined),
                          suffixText: 'Ha',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            error!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
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
                    final bjr = double.tryParse(
                      bjrC.text.trim().replaceAll(',', '.'),
                    );
                    final tahun = int.tryParse(tahunC.text.trim());
                    final luasText = luasC.text.trim().replaceAll(',', '.');
                    final luas = luasText.isEmpty ? null : double.tryParse(luasText);
                    final currentYear = DateTime.now().year;

                    if (kode.isEmpty) {
                      setDialogState(() => error = 'Kode blok wajib diisi.');
                      return;
                    }
                    if (bjr == null || bjr <= 0) {
                      setDialogState(() => error = 'BJR harus lebih dari 0.');
                      return;
                    }
                    if (tahun == null || tahun < 1900 || tahun > currentYear) {
                      setDialogState(
                        () => error = 'Tahun tanam harus antara 1900-$currentYear.',
                      );
                      return;
                    }
                    if (luasText.isNotEmpty && (luas == null || luas <= 0)) {
                      setDialogState(() => error = 'Luas blok harus lebih dari 0 Ha.');
                      return;
                    }

                    Navigator.pop(
                      dialogContext,
                      MasterBlok(
                        id: current?.id,
                        kode: kode,
                        bjr: bjr,
                        tahunTanam: tahun,
                        luasHa: luas,
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
    bjrC.dispose();
    tahunC.dispose();
    luasC.dispose();

    if (result == null) return;

    try {
      if (current == null) {
        await DatabaseHelper.instance.addMasterBlok(result);
      } else {
        await DatabaseHelper.instance.updateMasterBlok(result);
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              current == null
                  ? 'Blok berhasil ditambahkan.'
                  : 'Blok berhasil diperbarui.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kode blok sudah digunakan.')),
        );
      }
    }
  }

  Future<void> _delete(MasterBlok b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text('Hapus Blok?'),
        content: Text(
          '${b.kode}\n${_bjrText(b.bjr)} • ${_ttText(b.tahunTanam)}',
        ),
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
    if (ok == true && b.id != null) {
      await DatabaseHelper.instance.deleteMasterBlok(b.id!);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = filteredItems;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F6),
      appBar: AppBar(
        title: const Text(
          'Master Blok',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: green,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchC,
                          decoration: InputDecoration(
                            hintText: 'Cari blok...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: searchC.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: searchC.clear,
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE1E7E1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFFE1E7E1),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 52,
                        height: 52,
                        child: FilledButton(
                          onPressed: () => _form(),
                          style: FilledButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Icon(Icons.add_rounded, size: 27),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (data.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 34),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE1E7E1)),
                      ),
                      child: Text(
                        items.isEmpty
                            ? 'Belum ada Master Blok.'
                            : 'Blok tidak ditemukan.',
                        style: const TextStyle(color: muted),
                      ),
                    ),
                  for (final b in data) ...[
                    _BlokCard(
                      blok: b,
                      onEdit: () => _form(current: b),
                      onDelete: () => _delete(b),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
    );
  }
}

class _BlokCard extends StatelessWidget {
  final MasterBlok blok;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BlokCard({
    required this.blok,
    required this.onEdit,
    required this.onDelete,
  });

  String _bjr(double value) {
    if (value <= 0) return 'BJR belum diisi';
    return 'BJR ${value.toStringAsFixed(2).replaceAll('.', ',')} kg/jjg';
  }

  String _luas(double? value) {
    if (value == null || value <= 0) return 'Ha -';
    return '${value.toStringAsFixed(2).replaceAll('.', ',')} Ha';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 6, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E7E1), width: .9),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6EC),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.grid_view_rounded,
              color: _MasterBlokScreenState.green,
              size: 22,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  blok.kode,
                  style: const TextStyle(
                    color: Color(0xFF172119),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_bjr(blok.bjr)}  |  ${blok.tahunTanam == null ? 'TT belum diisi' : 'TT ${blok.tahunTanam}'}  |  ${_luas(blok.luasHa)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6F7972),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Hapus')),
            ],
          ),
        ],
      ),
    );
  }
}
