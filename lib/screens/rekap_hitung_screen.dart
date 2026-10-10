import 'dart:io';

import 'package:flutter/material.dart';

import '../app/date_utils.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../services/excel_export_service.dart';

class RekapHitungScreen extends StatefulWidget {
  final int refreshToken;

  const RekapHitungScreen({
    super.key,
    this.refreshToken = 0,
  });

  @override
  State<RekapHitungScreen> createState() => _RekapHitungScreenState();
}

class _RekapHitungScreenState extends State<RekapHitungScreen> {
  static const green = Color(0xFF176B2C);
  static const orange = Color(0xFFF47B0B);
  static const blue = Color(0xFF2A66A4);

  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();

  List<DataHitung> rows = [];

  bool loading = true;
  bool exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant RekapHitungScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  int get totalInput => rows.length;

  int get totalJanjang =>
      rows.fold<int>(0, (total, item) => total + item.janjang);

  int get totalPemanen =>
      rows.map((item) => item.noPemanen).toSet().length;

  Map<String, List<DataHitung>> get groupedByDate {
    final result = <String, List<DataHitung>>{};

    for (final item in rows) {
      result.putIfAbsent(item.tanggal, () => <DataHitung>[]).add(item);
    }

    return result;
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() => loading = true);
    }

    final data = await DatabaseHelper.instance.getDataHitungRentang(
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
      initialDateRange: DateTimeRange(
        start: startDate,
        end: endDate,
      ),
      helpText: 'Pilih Rentang Rekap',
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
      endDate = DateTime(now.year, now.month, now.day);
    });

    await _load();
  }

  Future<void> _exportExcel() async {
    if (rows.isEmpty) {
      _message('Tidak ada data pada periode yang dipilih.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Excel?'),
        content: Text(
          'Periode:\n'
          '${displayDate(startDate)} - ${displayDate(endDate)}\n\n'
          '$totalInput input • $totalPemanen pemanen • '
          '$totalJanjang janjang',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.table_view_outlined),
            label: const Text('Export'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => exporting = true);

    try {
      final File file = await ExcelExportService.exportDataHitung(
        startDate: startDate,
        endDate: endDate,
        rows: rows,
      );

      if (!mounted) return;

      await ExcelExportService.shareExcel(file);
    } catch (e) {
      if (mounted) {
        _message('Export Excel gagal: $e');
      }
    } finally {
      if (mounted) {
        setState(() => exporting = false);
      }
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  List<_PemanenSummary> _summaryForDate(List<DataHitung> items) {
    final map = <String, _PemanenSummary>{};

    for (final item in items) {
      final current = map[item.noPemanen];

      if (current == null) {
        map[item.noPemanen] = _PemanenSummary(
          no: item.noPemanen,
          nama: item.namaPemanen,
          inputCount: 1,
          totalJanjang: item.janjang,
        );
      } else {
        current.inputCount += 1;
        current.totalJanjang += item.janjang;
      }
    }

    final result = map.values.toList()
      ..sort((a, b) {
        final ai = int.tryParse(a.no);
        final bi = int.tryParse(b.no);

        if (ai != null && bi != null) {
          return ai.compareTo(bi);
        }

        return a.no.compareTo(b.no);
      });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final groups = groupedByDate;
    final dateKeys = groups.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F6),
      appBar: AppBar(
        title: const Text(
          'Rekap',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _RangeCard(
              startDate: startDate,
              endDate: endDate,
              onChoose: _chooseRange,
              onToday: _today,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    value: '$totalPemanen',
                    label: 'Pemanen',
                    icon: Icons.groups_rounded,
                    color: green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryCard(
                    value: '$totalInput',
                    label: 'Input',
                    icon: Icons.fact_check_outlined,
                    color: orange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryCard(
                    value: '$totalJanjang',
                    label: 'Janjang',
                    icon: Icons.eco_rounded,
                    color: blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed:
                  loading || exporting || rows.isEmpty ? null : _exportExcel,
              icon: exporting
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.table_view_outlined),
              label: Text(
                exporting ? 'MEMBUAT EXCEL...' : 'EXPORT / BAGIKAN EXCEL',
              ),
            ),
            const SizedBox(height: 22),
            const _SectionTitle('HASIL REKAP'),
            const SizedBox(height: 10),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 50),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (rows.isEmpty)
              const _EmptyCard()
            else
              ...dateKeys.map((key) {
                final items = groups[key]!;
                final summaries = _summaryForDate(items);

                final date = parseDateKey(key);
                final dailyTotal = items.fold<int>(
                  0,
                  (total, item) => total + item.janjang,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DateRekapCard(
                    date: date,
                    totalInput: items.length,
                    totalJanjang: dailyTotal,
                    summaries: summaries,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _RangeCard extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onChoose;
  final VoidCallback onToday;

  const _RangeCard({
    required this.startDate,
    required this.endDate,
    required this.onChoose,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5E8E3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Periode Rekap',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.date_range_outlined,
                  color: Color(0xFF176B2C),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    startDate == endDate
                        ? displayDate(startDate)
                        : '${displayDate(startDate)}\n'
                            's.d. ${displayDate(endDate)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onToday,
                    icon: const Icon(Icons.today_outlined),
                    label: const Text('Hari Ini'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onChoose,
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: const Text('Pilih Rentang'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E8E3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 6,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 25),
            const SizedBox(height: 6),
            FittedBox(
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 23,
          decoration: BoxDecoration(
            color: const Color(0xFF176B2C),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF176B2C),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _DateRekapCard extends StatelessWidget {
  final DateTime date;
  final int totalInput;
  final int totalJanjang;
  final List<_PemanenSummary> summaries;

  const _DateRekapCard({
    required this.date,
    required this.totalInput,
    required this.totalJanjang,
    required this.summaries,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE5E8E3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFEAF5E7),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    color: Color(0xFF176B2C),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    displayDayDate(date),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$totalJanjang Janjang',
                      style: const TextStyle(
                        color: Color(0xFF176B2C),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$totalInput input',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 22),
            ...summaries.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: const Color(0xFFF1F4EF),
                      child: Text(
                        item.no,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF176B2C),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.nama,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${item.inputCount} kali input',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${item.totalJanjang} Janjang',
                      style: const TextStyle(
                        color: Color(0xFF176B2C),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 40,
              color: Colors.black38,
            ),
            SizedBox(height: 10),
            Text(
              'Belum ada Data Hitung pada periode ini.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PemanenSummary {
  final String no;
  final String nama;
  int inputCount;
  int totalJanjang;

  _PemanenSummary({
    required this.no,
    required this.nama,
    required this.inputCount,
    required this.totalJanjang,
  });
}
