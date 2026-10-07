import 'package:flutter/material.dart';

import '../app/date_utils.dart';
import '../database/database_helper.dart';
import '../models/info_pemanen_model.dart';
import '../models/models.dart';
import 'rekap_shared.dart';

class RekapPemanenScreen extends StatefulWidget {
  const RekapPemanenScreen({super.key});

  @override
  State<RekapPemanenScreen> createState() => _RekapPemanenScreenState();
}

class _RekapPemanenScreenState extends State<RekapPemanenScreen> {
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();

  List<DataHitung> hitungRows = [];
  List<DataTruk> trukRows = [];
  List<InfoPemanen> infoRows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, _PemanenSummary> get summaries {
    final map = <String, _PemanenSummary>{};

    _PemanenSummary obtain(String no, String nama) {
      final cleanNo = no.trim();
      final key = cleanNo.isEmpty ? 'nama:${nama.trim()}' : cleanNo;
      return map.putIfAbsent(
        key,
        () => _PemanenSummary(noPemanen: cleanNo, namaPemanen: nama.trim()),
      );
    }

    for (final row in hitungRows) {
      final item = obtain(row.noPemanen, row.namaPemanen);
      item.hitungJanjang += row.janjang;
      item.hitungInput++;
      if (row.blok.trim().isNotEmpty) item.blok.add(row.blok);
    }

    for (final row in infoRows) {
      final item = obtain(row.noPemanen, row.namaPemanen);
      item.infoJanjang += row.janjang;
      item.infoInput++;
      if (row.blok.trim().isNotEmpty) item.blok.add(row.blok);
    }

    for (final row in trukRows) {
      final item = obtain(row.noPemanen, row.pemanen);
      item.angkutJanjang += row.janjang;
      item.angkutInput++;
      if (row.blok.trim().isNotEmpty) item.blok.add(row.blok);
      if (row.namaTruk.trim().isNotEmpty) item.truk.add(row.namaTruk);
    }

    return map;
  }

  int get totalHitung =>
      hitungRows.fold<int>(0, (total, row) => total + row.janjang);
  int get totalAngkut =>
      trukRows.fold<int>(0, (total, row) => total + row.janjang);

  int _comparePemanen(_PemanenSummary a, _PemanenSummary b) {
    final ai = int.tryParse(a.noPemanen);
    final bi = int.tryParse(b.noPemanen);
    if (ai != null && bi != null) return ai.compareTo(bi);
    if (a.noPemanen.isEmpty && b.noPemanen.isNotEmpty) return 1;
    if (a.noPemanen.isNotEmpty && b.noPemanen.isEmpty) return -1;
    return a.namaPemanen.compareTo(b.namaPemanen);
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    final awal = dateKey(startDate);
    final akhir = dateKey(endDate);
    final result = await Future.wait([
      DatabaseHelper.instance.getDataHitungRentang(awal, akhir),
      DatabaseHelper.instance.getDataTrukRentang(awal, akhir),
      DatabaseHelper.instance.getInfoPemanenRentang(awal, akhir),
    ]);
    if (!mounted) return;
    setState(() {
      hitungRows = result[0] as List<DataHitung>;
      trukRows = result[1] as List<DataTruk>;
      infoRows = result[2] as List<InfoPemanen>;
      loading = false;
    });
  }

  Future<void> _chooseRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
      helpText: 'Pilih Rentang Rekap per Pemanen',
      saveText: 'TERAPKAN',
    );
    if (selected == null) return;
    setState(() {
      startDate = selected.start;
      endDate = selected.end;
    });
    await _load();
  }

  Future<void> _today() async {
    final now = DateTime.now();
    setState(() {
      startDate = DateTime(now.year, now.month, now.day);
      endDate = startDate;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = summaries.values.toList()..sort(_comparePemanen);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F6),
      appBar: AppBar(
        title: const Text(
          'Rekap per Pemanen',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          children: [
            RekapRangeCard(
              startDate: startDate,
              endDate: endDate,
              onChooseRange: _chooseRange,
              onToday: _today,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RekapMetricCard(
                    icon: Icons.groups_rounded,
                    label: 'Pemanen',
                    value: '${items.length}',
                    tint: const Color(0xFFF0E9FF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RekapMetricCard(
                    icon: Icons.calculate_rounded,
                    label: 'Janjang Hitung',
                    value: formatRekapNumber(totalHitung),
                    tint: const Color(0xFFEAF5E7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: RekapMetricCard(
                    icon: Icons.local_shipping_rounded,
                    label: 'Janjang Angkut',
                    value: formatRekapNumber(totalAngkut),
                    tint: const Color(0xFFE8F0FF),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RekapMetricCard(
                    icon: Icons.edit_note_rounded,
                    label: 'Total Input',
                    value: '${hitungRows.length + infoRows.length + trukRows.length}',
                    tint: const Color(0xFFFFF0D8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Ringkasan Pemanen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1D271E),
              ),
            ),
            const SizedBox(height: 10),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (items.isEmpty)
              const RekapEmptyState(
                message: 'Belum ada data pemanen pada periode yang dipilih.',
              )
            else
              ...items.map(_pemanenCard),
          ],
        ),
      ),
    );
  }

  Widget _pemanenCard(_PemanenSummary item) {
    final no = item.noPemanen.isEmpty ? '-' : item.noPemanen;
    final blokText = item.blok.isEmpty ? '-' : (item.blok.toList()..sort()).join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E8E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0E9FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, color: rekapGreen),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$no • ${item.namaPemanen}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Blok: $blokText',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF687168), fontSize: 12.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _valueRow('Data Hitung', item.hitungJanjang, item.hitungInput),
          const Divider(height: 16),
          _valueRow('Info Pemanen', item.infoJanjang, item.infoInput),
          const Divider(height: 16),
          _valueRow('Data Truk', item.angkutJanjang, item.angkutInput),
          const SizedBox(height: 10),
          Text(
            '${item.blok.length} blok • ${item.truk.length} truk',
            style: const TextStyle(
              color: Color(0xFF758075),
              fontSize: 11.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueRow(String label, int janjang, int input) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '$input input',
          style: const TextStyle(color: Color(0xFF758075), fontSize: 11.8),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 72,
          child: Text(
            formatRekapNumber(janjang),
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: rekapGreen,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _PemanenSummary {
  final String noPemanen;
  final String namaPemanen;
  int hitungJanjang = 0;
  int hitungInput = 0;
  int infoJanjang = 0;
  int infoInput = 0;
  int angkutJanjang = 0;
  int angkutInput = 0;
  final Set<String> blok = {};
  final Set<String> truk = {};

  _PemanenSummary({required this.noPemanen, required this.namaPemanen});
}
