import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app/date_utils.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../widgets/header_image_art.dart';

class RekapTrukScreen extends StatefulWidget {
  const RekapTrukScreen({super.key});

  @override
  State<RekapTrukScreen> createState() => _RekapTrukScreenState();
}

class _RekapTrukScreenState extends State<RekapTrukScreen> {
  static const green = Color(0xFF176B2C);

  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now();

  List<DataTruk> rows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int get totalJanjang =>
      rows.fold<int>(0, (sum, item) => sum + item.janjang);


  int get totalTruk =>
      rows.map((e) => e.namaTruk).toSet().length;

  int get totalPemanen =>
      rows.map((e) => e.noPemanen).toSet().length;

  int get rataRataJanjangTruk =>
      totalTruk == 0 ? 0 : (totalJanjang / totalTruk).round();

  Map<String, List<DataTruk>> get groupedByDate {
    final result = <String, List<DataTruk>>{};
    for (final item in rows) {
      result.putIfAbsent(item.tanggal, () => <DataTruk>[]).add(item);
    }
    return result;
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);

    final data = await DatabaseHelper.instance.getDataTrukRentang(
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
      helpText: 'Pilih Periode Rekap Data Truk',
      saveText: 'TERAPKAN',
    );

    if (selected == null) return;

    setState(() {
      startDate = selected.start;
      endDate = selected.end;
    });

    await _load();
  }


  String _generateWhatsappText() {
    final buffer = StringBuffer();

    buffer.writeln('🌴 *REKAP DATA TRUK*');
    buffer.writeln('📅 Periode: $_periodText');
    buffer.writeln('');

    buffer.writeln('====================');
    buffer.writeln('🚚 *REKAP PER TRUK*');
    buffer.writeln('====================');

    final truckMap = <String, List<DataTruk>>{};
    for (final item in rows) {
      truckMap.putIfAbsent(item.namaTruk, () => []).add(item);
    }

    final trucks = truckMap.keys.toList()..sort();

    for (final truck in trucks) {
      final data = truckMap[truck]!;
      final total = data.fold<int>(0, (s, e) => s + e.janjang);
      buffer.writeln('');
      buffer.writeln('🚛 $truck');

      final blockMap = <String, int>{};
      for (final item in data) {
        blockMap[item.blok] = (blockMap[item.blok] ?? 0) + item.janjang;
      }

      for (final block in blockMap.keys) {
        buffer.writeln('- Blok $block : ${blockMap[block]} jjg');
      }
      buffer.writeln('Total : $total jjg');
    }

    buffer.writeln('');
    buffer.writeln('====================');
    buffer.writeln('🌿 *REKAP PER BLOK*');
    buffer.writeln('====================');

    final blockMap = <String, int>{};
    for (final item in rows) {
      blockMap[item.blok] = (blockMap[item.blok] ?? 0) + item.janjang;
    }
    for (final block in (blockMap.keys.toList()..sort())) {
      buffer.writeln('Blok $block : ${blockMap[block]} jjg');
    }

    buffer.writeln('');
    buffer.writeln('====================');
    buffer.writeln('👷 *REKAP PER PEMANEN*');
    buffer.writeln('====================');

    for (final item in _groupPemanenTotals(rows)) {
      buffer.writeln('${item.noPemanen.isEmpty ? '-' : item.noPemanen} - ${item.namaPemanen} :  ${item.janjang} ');
    }

    buffer.writeln('');
    buffer.writeln('====================');
    buffer.writeln('TOTAL PRODUKSI');
    buffer.writeln('====================');
    buffer.writeln('🚚 Total Truk : $totalTruk');
    buffer.writeln('👷 Total Pemanen : $totalPemanen');
    buffer.writeln('🌴 Total Janjang : $totalJanjang jjg');
    buffer.writeln('');

    return buffer.toString();
  }


  Future<void> _shareWhatsapp() async {
    if (rows.isEmpty) return;
    await Share.share(_generateWhatsappText());
  }


  String get _periodText {
    if (startDate == endDate) return displayDate(startDate);
    return '${displayDate(startDate)} s/d ${displayDate(endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final dateMap = groupedByDate;
    final dates = dateMap.keys.toList()..sort();

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _CompactTruckHeader(
              onBack: () => Navigator.pop(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: _chooseRange,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF5E7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 15,
                              color: green,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _periodText,
                              style: const TextStyle(
                                color: green,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  if (loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: CircularProgressIndicator(),
                    )
                  else if (rows.isEmpty)
                    const _EmptyCompactCard()
                  else ...[
                    ...dates.map(
                      (date) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CompactDateGroup(
                          date: date,
                          rows: dateMap[date]!,
                        ),
                      ),
                    ),
                    _CompactGrandTotal(total: totalJanjang),
                    const SizedBox(height: 10),
                    _RekapTotalPerBlok(rows: rows),
                    const SizedBox(height: 8),
                    _RekapPemanen(rows: rows),
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _shareWhatsapp,
                            icon: const Icon(Icons.share_rounded),
                            label: const Text('BAGIKAN WHATSAPP'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class _CompactTruckHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _CompactTruckHeader({
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 115,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF176B2C),
                  Color(0xFF0C5B27),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          HeaderImageArt(
            assetPath: 'assets/headers/data_truk_header_art.png',
            widthFactor: .58,
            opacity: 1,
            fit: BoxFit.contain,
            child: const SizedBox.expand(),
          ),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 5, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Text(
                      'Rekap Data Truk',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -1,
            height: 28,
            child: ClipPath(
              clipper: _HeaderWaveClipper(),
              child: Container(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, size.height * .46)
      ..quadraticBezierTo(
        size.width * .18,
        size.height * .05,
        size.width * .42,
        size.height * .38,
      )
      ..quadraticBezierTo(
        size.width * .70,
        size.height * .78,
        size.width,
        size.height * .26,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _CompactDateGroup extends StatelessWidget {
  final String date;
  final List<DataTruk> rows;

  const _CompactDateGroup({
    required this.date,
    required this.rows,
  });

  Map<String, List<DataTruk>> get byTruck {
    final map = <String, List<DataTruk>>{};
    for (final item in rows) {
      map.putIfAbsent(item.namaTruk, () => <DataTruk>[]).add(item);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final trucks = byTruck;
    final names = trucks.keys.toList()..sort();

    return Column(
      children: names
          .map(
            (name) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _CompactTruckCard(
                name: name,
                rows: trucks[name]!,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _CompactTruckCard extends StatelessWidget {
  final String name;
  final List<DataTruk> rows;

  const _CompactTruckCard({
    required this.name,
    required this.rows,
  });

  int get total =>
      rows.fold<int>(0, (sum, item) => sum + item.janjang);

  Map<String, List<DataTruk>> get byBlock {
    final map = <String, List<DataTruk>>{};
    for (final item in rows) {
      map.putIfAbsent(item.blok, () => <DataTruk>[]).add(item);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF176B2C);
    final blocks = byBlock;
    final blockNames = blocks.keys.toList()..sort();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFD7DDD5),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 6, 8, 6),
            child: Row(
              children: [
                const Icon(
                  Icons.local_shipping_rounded,
                  size: 19,
                  color: green,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  'Total: $total',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 18,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...blockNames.map(
            (block) => _CompactBlock(
              name: block,
              rows: blocks[block]!,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 7,
            ),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Color(0xFFE1E5DF),
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Total $name',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: green,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '$total',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: green,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _PemanenTotal {
  final String noPemanen;
  final String namaPemanen;
  int janjang;

  _PemanenTotal({
    required this.noPemanen,
    required this.namaPemanen,
    required this.janjang,
  });
}

List<_PemanenTotal> _groupPemanenTotals(List<DataTruk> rows) {
  final map = <String, _PemanenTotal>{};

  for (final item in rows) {
    final no = item.noPemanen.trim();
    final nama = item.pemanen.trim();

    // Gunakan no pemanen sebagai identitas utama.
    // Data lama tanpa nomor menggunakan nama sebagai fallback.
    final key = no.isNotEmpty
        ? 'NO::$no'
        : 'NAME::${nama.toLowerCase()}';

    final current = map[key];

    if (current == null) {
      map[key] = _PemanenTotal(
        noPemanen: no,
        namaPemanen: nama,
        janjang: item.janjang,
      );
    } else {
      current.janjang += item.janjang;
    }
  }

  final result = map.values.toList()
    ..sort((a, b) {
      final ai = int.tryParse(a.noPemanen);
      final bi = int.tryParse(b.noPemanen);

      if (ai != null && bi != null) {
        return ai.compareTo(bi);
      }

      if (a.noPemanen.isNotEmpty && b.noPemanen.isNotEmpty) {
        return a.noPemanen.compareTo(b.noPemanen);
      }

      return a.namaPemanen
          .toLowerCase()
          .compareTo(b.namaPemanen.toLowerCase());
    });

  return result;
}


class _CompactBlock extends StatelessWidget {
  final String name;
  final List<DataTruk> rows;

  const _CompactBlock({
    required this.name,
    required this.rows,
  });

  int get subtotal =>
      rows.fold<int>(0, (sum, item) => sum + item.janjang);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFFF3F5F2),
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 4,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Blok $name',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'Subtotal: $subtotal',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        ..._groupPemanenTotals(rows).map(
          (item) => Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Color(0xFFE7EAE6),
                  width: .7,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 4,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  child: Text(
                    item.noPemanen.isEmpty
                        ? '-'
                        : item.noPemanen,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    item.namaPemanen,
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${item.janjang}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RekapTotalPerBlok extends StatelessWidget {
  final List<DataTruk> rows;

  const _RekapTotalPerBlok({required this.rows});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF176B2C);
    final byBlok = <String, List<DataTruk>>{};
    for (final row in rows) {
      final blok = row.blok.trim().isEmpty ? '-' : row.blok.trim();
      byBlok.putIfAbsent(blok, () => []).add(row);
    }
    final blokNames = byBlok.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final grandTotal = rows.fold<int>(0, (sum, item) => sum + item.janjang);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFD7DDD5)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F1E5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            ),
            child: const Text('REKAP PER BLOK', style: TextStyle(color: green, fontSize: 13, fontWeight: FontWeight.w900)),
          ),
          ...blokNames.expand((blok) {
            final blockRows = byBlok[blok]!;
            final pemanenTotals = _groupPemanenTotals(blockRows);
            final blockTotal = blockRows.fold<int>(0, (sum, item) => sum + item.janjang);
            final widgets = <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 7),
                color: const Color(0xFFF5F8F4),
                child: Text('BLOK $blok', style: const TextStyle(color: green, fontSize: 12.5, fontWeight: FontWeight.w900)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE1E5DF)))),
                child: const Row(children: [
                  SizedBox(width: 55, child: Text('No', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))),
                  Expanded(child: Text('Nama', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))),
                  SizedBox(width: 90, child: Text('Janjang', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800))),
                ]),
              ),
            ];
            widgets.addAll(pemanenTotals.map((item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE7EAE6), width: .7))),
              child: Row(children: [
                SizedBox(width: 55, child: Text(item.noPemanen.isEmpty ? '-' : item.noPemanen, style: const TextStyle(fontSize: 12))),
                Expanded(child: Text(item.namaPemanen, style: const TextStyle(fontSize: 12))),
                SizedBox(width: 90, child: Text('${item.janjang}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
              ]),
            )));
            widgets.add(Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: const BoxDecoration(color: Color(0xFFF0F5ED), border: Border(bottom: BorderSide(color: Color(0xFFD7DDD5)))),
              child: Row(children: [
                const SizedBox(width: 55),
                Expanded(child: Text('TOTAL BLOK $blok', style: const TextStyle(color: green, fontSize: 12, fontWeight: FontWeight.w900))),
                SizedBox(width: 90, child: Text('$blockTotal', textAlign: TextAlign.right, style: const TextStyle(color: green, fontSize: 13.5, fontWeight: FontWeight.w900))),
              ]),
            ));
            return widgets;
          }),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(bottom: Radius.circular(6))),
            child: Row(children: [
              const SizedBox(width: 55),
              const Expanded(child: Text('TOTAL SEMUA BLOK', style: TextStyle(color: green, fontSize: 12.5, fontWeight: FontWeight.w900))),
              SizedBox(width: 90, child: Text('$grandTotal', textAlign: TextAlign.right, style: const TextStyle(color: green, fontSize: 14, fontWeight: FontWeight.w900))),
            ]),
          ),
        ],
      ),
    );
  }
}

class _CompactGrandTotal extends StatelessWidget {
  final int total;

  const _CompactGrandTotal({
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF087329),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Center(
              child: Text(
                'TOTAL KESELURUHAN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          Container(
            width: 94,
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Color(0x55FFFFFF),
                ),
              ),
            ),
            child: Center(
              child: Text(
                '$total',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class _RekapPemanen extends StatelessWidget {
  final List<DataTruk> rows;

  const _RekapPemanen({required this.rows});

  @override
  Widget build(BuildContext context) {
    final Map<String, int> totals = {};
    final Map<String, String> names = {};
    for (final item in rows) {
      final key = item.noPemanen.isEmpty ? item.pemanen : item.noPemanen;
      totals[key] = (totals[key] ?? 0) + item.janjang;
      names[key] = item.pemanen;
    }

    final entries = totals.entries.toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(10),
            child: Text(
              'REKAP PEMANEN',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          ...entries.map((e) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFE1E5DF)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${e.key} - ${names[e.key] ?? '-'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      '${e.value} Janjang',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _EmptyCompactCard extends StatelessWidget {
  const _EmptyCompactCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 45),
      child: Column(
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 42,
            color: Colors.black38,
          ),
          SizedBox(height: 8),
          Text('Belum ada Data Truk pada periode ini.'),
        ],
      ),
    );
  }
}
