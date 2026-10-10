import 'package:flutter/material.dart';

import '../app/date_utils.dart';
import '../database/database_helper.dart';
import '../models/info_pemanen_model.dart';
import 'rekap_shared.dart';

class RekapInfoPemanenScreen extends StatefulWidget {
  const RekapInfoPemanenScreen({super.key});

  @override
  State<RekapInfoPemanenScreen> createState() => _RekapInfoPemanenScreenState();
}

class _RekapInfoPemanenScreenState extends State<RekapInfoPemanenScreen> {
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();
  List<InfoPemanen> rows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int get totalJanjang =>
      rows.fold<int>(0, (total, item) => total + item.janjang);

  int get totalPemanen => rows.map((e) => e.noPemanen).toSet().length;

  int get totalBlok =>
      rows.map((e) => e.blok).where((e) => e.trim().isNotEmpty).toSet().length;

  Map<String, _PemanenInfoSummary> get summaries {
    final map = <String, _PemanenInfoSummary>{};
    for (final row in rows) {
      final key = row.noPemanen.trim().isEmpty
          ? 'nama:${row.namaPemanen}'
          : row.noPemanen;
      final summary = map.putIfAbsent(
        key,
        () => _PemanenInfoSummary(
          noPemanen: row.noPemanen,
          namaPemanen: row.namaPemanen,
        ),
      );
      summary.totalJanjang += row.janjang;
      summary.totalInput++;
      if (row.blok.trim().isNotEmpty) summary.blok.add(row.blok);
      summary.tanggal.add(row.tanggal);
    }
    final result = map.values.toList();
    result.sort((a, b) => _comparePemanenNo(a.noPemanen, b.noPemanen));
    return {for (final item in result) item.key: item};
  }

  int _comparePemanenNo(String a, String b) {
    final ai = int.tryParse(a);
    final bi = int.tryParse(b);
    if (ai != null && bi != null) return ai.compareTo(bi);
    return a.compareTo(b);
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    final data = await DatabaseHelper.instance.getInfoPemanenRentang(
      dateKey(startDate),
      dateKey(endDate),
    );
    if (!mounted) return;
    setState(() {
      rows = data;
      loading = false;
    });
  }

  Future<void> _chooseRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
      helpText: 'Pilih Rentang Rekap Info Pemanen',
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
    final summaryList = summaries.values.toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F6),
      appBar: AppBar(
        title: const Text(
          'Rekap Info Pemanen',
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
                    icon: Icons.grain_rounded,
                    label: 'Total Janjang',
                    value: formatRekapNumber(totalJanjang),
                    tint: const Color(0xFFEAF5E7),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RekapMetricCard(
                    icon: Icons.groups_rounded,
                    label: 'Pemanen',
                    value: '$totalPemanen',
                    tint: const Color(0xFFF0E9FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: RekapMetricCard(
                    icon: Icons.map_rounded,
                    label: 'Blok',
                    value: '$totalBlok',
                    tint: const Color(0xFFFFF0D8),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RekapMetricCard(
                    icon: Icons.edit_note_rounded,
                    label: 'Jumlah Input',
                    value: '${rows.length}',
                    tint: const Color(0xFFE8F0FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Ringkasan per Pemanen',
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
            else if (summaryList.isEmpty)
              const RekapEmptyState(
                message: 'Belum ada Info Pemanen pada periode yang dipilih.',
              )
            else
              ...summaryList.map(_summaryCard),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(_PemanenInfoSummary item) {
    final no = item.noPemanen.trim().isEmpty ? '-' : item.noPemanen;
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
                  color: Color(0xFFEAF5E7),
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
                      style: const TextStyle(color: Color(0xFF687168), fontSize: 12.4),
                    ),
                  ],
                ),
              ),
              Text(
                formatRekapNumber(item.totalJanjang),
                style: const TextStyle(
                  color: rekapGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _smallStat('Input', '${item.totalInput}'),
              _smallStat('Hari', '${item.tanggal.length}'),
              _smallStat('Blok', '${item.blok.length}'),
              _smallStat('Janjang', formatRekapNumber(item.totalJanjang)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallStat(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF233024)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10.8, color: Color(0xFF758075)),
          ),
        ],
      ),
    );
  }
}

class _PemanenInfoSummary {
  final String noPemanen;
  final String namaPemanen;
  int totalJanjang = 0;
  int totalInput = 0;
  final Set<String> blok = {};
  final Set<String> tanggal = {};

  _PemanenInfoSummary({required this.noPemanen, required this.namaPemanen});

  String get key => noPemanen.trim().isEmpty ? 'nama:$namaPemanen' : noPemanen;
}
