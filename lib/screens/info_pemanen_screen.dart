import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app/date_utils.dart';
import '../database/database_helper.dart';
import '../models/info_pemanen_model.dart';
import '../models/models.dart';

class InfoPemanenScreen extends StatefulWidget {
  const InfoPemanenScreen({super.key});

  @override
  State<InfoPemanenScreen> createState() => _InfoPemanenScreenState();
}

class _InfoPemanenScreenState extends State<InfoPemanenScreen> {
  static const green = Color(0xFF176B2C);

  final db = DatabaseHelper.instance;
  final janjangController = TextEditingController();
  final janjangFocus = FocusNode();

  DateTime date = DateTime.now();

  List<Pemanen> pemanen = [];
  List<MasterBlok> blok = [];
  List<InfoPemanen> rows = [];

  String? selectedPemanenNo;
  String? selectedBlokKode;
  bool sharing = false;

  Pemanen? get selectedPemanen {
    if (selectedPemanenNo == null) return null;

    for (final p in pemanen) {
      if (p.no == selectedPemanenNo) return p;
    }

    return null;
  }

  MasterBlok? get selectedMasterBlok {
    final kode = selectedBlokKode;
    if (kode == null) return null;
    for (final b in blok) {
      if (b.kode == kode) return b;
    }
    return null;
  }

  int get totalJanjang =>
      rows.fold(0, (sum, item) => sum + item.janjang);

  int get jumlahPemanen =>
      rows.map((e) => e.noPemanen).toSet().length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    janjangController.dispose();
    janjangFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final key = dateKey(date);
    final b = await db.getBlokPanenTanggal(key);
    final h = await db.getInfoPemanenTanggal(key);

    String? nextBlok = selectedBlokKode;
    if (nextBlok != null && !b.any((x) => x.kode == nextBlok)) {
      nextBlok = null;
    }

    final p = nextBlok == null
        ? <Pemanen>[]
        : await db.getPemanenBlokTanggal(key, nextBlok);

    String? nextPemanen = selectedPemanenNo;
    if (nextPemanen != null && !p.any((x) => x.no == nextPemanen)) {
      nextPemanen = null;
    }

    if (!mounted) return;

    setState(() {
      pemanen = p;
      blok = b;
      rows = h;
      selectedPemanenNo = nextPemanen;
      selectedBlokKode = nextBlok;
    });
  }

  Future<void> _loadPemanenForSelectedBlok() async {
    final kode = selectedBlokKode;
    final p = kode == null
        ? <Pemanen>[]
        : await db.getPemanenBlokTanggal(dateKey(date), kode);

    String? nextPemanen = selectedPemanenNo;
    if (nextPemanen != null && !p.any((x) => x.no == nextPemanen)) {
      nextPemanen = null;
    }

    if (!mounted) return;
    setState(() {
      pemanen = p;
      selectedPemanenNo = nextPemanen;
    });
  }

  Future<void> _chooseDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (selected == null) return;

    setState(() => date = selected);
    await _load();
  }

  Future<void> _save() async {
    final p = selectedPemanen;
    final j = int.tryParse(janjangController.text.trim());

    if (blok.isEmpty) {
      _message('Belum ada blok panen untuk tanggal ini. Atur Absensi Per Blok terlebih dahulu.');
      return;
    }
    if (pemanen.isEmpty) {
      _message('Belum ada pemanen pada blok yang dipilih. Atur Absensi Per Blok terlebih dahulu.');
      return;
    }
    if (selectedBlokKode == null || selectedBlokKode!.isEmpty) {
      _message('Pilih blok terlebih dahulu.');
      return;
    }

    if (p == null) {
      _message('Pilih pemanen terlebih dahulu.');
      return;
    }

    if (j == null || j <= 0) {
      _message('Masukkan jumlah janjang yang benar.');
      return;
    }

    final stillActive = await db.isPemanenAktifDiBlok(
      tanggal: dateKey(date),
      kodeBlok: selectedBlokKode!,
      noPemanen: p.no,
    );
    if (!stillActive) {
      await _load();
      _message(
        'Penempatan pemanen pada blok ini sudah berubah. Pilih ulang blok dan pemanen.',
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Konfirmasi Simpan'),
        content: Text(
          'Tanggal: ${displayDate(date)}\n'
          'Blok: ${selectedBlokKode ?? '-'}\n'
          '${selectedMasterBlok?.detailSingkat ?? ''}\n'
          'Pemanen: ${p.no} • ${p.nama}\n'
          'Janjang: $j\n\n'
          'Simpan ke Info Pemanen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await db.addInfoPemanen(
      InfoPemanen(
        tanggal: dateKey(date),
        jamInput: timeText(DateTime.now()),
        noPemanen: p.no,
        namaPemanen: p.nama,
        blok: selectedBlokKode!,
        janjang: j,
      ),
    );

    janjangController.clear();
    await _load();

    if (!mounted) return;

    _message('Info Pemanen berhasil disimpan.');
    janjangFocus.requestFocus();
  }


  Future<void> _edit(InfoPemanen item) async {
    final c = TextEditingController(text: item.janjang.toString());

    final value = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Janjang'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(dialogContext);
            },
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(dialogContext, int.tryParse(c.text.trim()));
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (value == null || item.id == null) {
      c.dispose();
      return;
    }

    if (value <= 0) {
      c.dispose();
      if (mounted) {
        _message('Jumlah janjang harus lebih dari 0.');
      }
      return;
    }

    try {
      await db.updateInfoPemanen(
        InfoPemanen(
          id: item.id,
          tanggal: item.tanggal,
          jamInput: item.jamInput,
          noPemanen: item.noPemanen,
          namaPemanen: item.namaPemanen,
          blok: item.blok,
          janjang: value,
        ),
      );

      if (!mounted) return;

      await Future<void>.delayed(Duration.zero);
      await _load();
    } finally {
      c.dispose();
    }
  }

  Future<void> _showItemMenu(InfoPemanen item) async {
    final a=await showModalBottomSheet<String>(context:context,builder:(c)=>SafeArea(child:Wrap(children:[
      ListTile(leading:const Icon(Icons.edit),title:const Text('Edit'),onTap:()=>Navigator.pop(c,'edit')),
      ListTile(leading:const Icon(Icons.delete),title:const Text('Hapus'),onTap:()=>Navigator.pop(c,'hapus')),
    ])));
    if(a=='edit') await _edit(item);
    if(a=='hapus') await _delete(item);
  }

  Future<void> _delete(InfoPemanen item) async {
    if (item.id == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Info Pemanen?'),
        content: Text(
          '${item.noPemanen} • ${item.namaPemanen}\n'
          '${item.janjang} Janjang',
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

    if (ok == true) {
      await db.deleteInfoPemanen(item.id!);
      await _load();
    }
  }

  Future<void> _shareWhatsapp() async {
    if (rows.isEmpty) {
      _message('Belum ada Info Pemanen pada tanggal ini.');
      return;
    }

    setState(() => sharing = true);

    final buffer = StringBuffer();
    buffer.writeln('INFO PEMANEN');
    buffer.writeln('Tanggal: ${displayDate(date)}');
    buffer.writeln('');

    for (final item in rows) {
      buffer.writeln(
        '${item.blok.isEmpty ? '-' : item.blok} • ${item.noPemanen} - ${item.namaPemanen}: ${item.janjang} Janjang',
      );
    }

    buffer.writeln('');
    buffer.writeln('Total Pemanen: $jumlahPemanen Orang');
    buffer.writeln('Total Janjang: $totalJanjang');

    await Share.share(buffer.toString());

    if (mounted) {
      setState(() => sharing = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF176B2C),
        foregroundColor: Colors.white,
        title: const Text(
          'Info Pemanen',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const Text(
              'DATA PEMANEN HARI INI',
              style: TextStyle(
                color: Color(0xFF176B2C),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _chooseDate,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal',
                  prefixIcon: Icon(Icons.calendar_month_outlined),
                ),
                child: Text(displayDate(date)),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _Summary(
                    value: '$jumlahPemanen',
                    label: 'Pemanen',
                    icon: Icons.groups_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Summary(
                    value: '$totalJanjang',
                    label: 'Janjang',
                    icon: Icons.eco_rounded,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            const Text(
              'INPUT INFO PEMANEN',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: green,
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedBlokKode != null &&
                      blok.any((b) => b.kode == selectedBlokKode)
                  ? selectedBlokKode
                  : null,
              decoration: const InputDecoration(
                labelText: 'Blok',
                prefixIcon: Icon(Icons.grid_view_outlined),
              ),
              items: blok
                  .map(
                    (b) => DropdownMenuItem<String>(
                      value: b.kode,
                      child: Text(
                        '${b.kode}  |  ${b.detailSingkat}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) async {
                setState(() {
                  selectedBlokKode = v;
                  selectedPemanenNo = null;
                });
                await _loadPemanenForSelectedBlok();
              },
              hint: Text(
                blok.isEmpty
                    ? 'Atur Absensi Per Blok untuk tanggal ini'
                    : 'Pilih blok',
              ),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              isExpanded: true,
              value: selectedPemanenNo != null &&
                      pemanen.any(
                        (p) => p.no == selectedPemanenNo,
                      )
                  ? selectedPemanenNo
                  : null,
              decoration: const InputDecoration(
                labelText: 'Nama Pemanen',
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: pemanen
                  .map(
                    (p) => DropdownMenuItem<String>(
                      value: p.no,
                      child: Text(
                        '${p.no} • ${p.nama}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              selectedItemBuilder: (context) => pemanen
                  .map(
                    (p) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${p.no} • ${p.nama}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() => selectedPemanenNo = v);
              },
              hint: Text(
                pemanen.isEmpty
                    ? (selectedBlokKode == null
                        ? 'Pilih blok terlebih dahulu'
                        : 'Belum ada pemanen di blok ini')
                    : 'Pilih pemanen',
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: janjangController,
              focusNode: janjangFocus,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'Janjang',
                prefixIcon: Icon(Icons.eco_outlined),
                suffixText: 'Janjang',
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text(
                  'SIMPAN INFO',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: rows.isEmpty || sharing ? null : _shareWhatsapp,
                icon: sharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.share_outlined),
                label: Text(
                  sharing ? 'MEMBUKA WHATSAPP...' : 'BAGIKAN WHATSAPP',
                ),
              ),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'DATA PEMANEN',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: green,
                    ),
                  ),
                ),
                Text(
                  '${rows.length} input',
                  style: const TextStyle(
                    color: green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (rows.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'Belum ada Info Pemanen pada tanggal ini.',
                    ),
                  ),
                ),
              )
            else
              ...rows.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEAF5E7),
                        child: Text(item.noPemanen),
                      ),
                      title: Text(
                        item.namaPemanen,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${item.blok.isEmpty ? '-' : item.blok} • ${item.jamInput} • ${item.janjang} Janjang',
                      ),
                      onLongPress: () => _showItemMenu(item),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _Summary({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 12,
        ),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFEAF5E7),
              child: Icon(
                icon,
                color: const Color(0xFF176B2C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF176B2C),
              ),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }
}

