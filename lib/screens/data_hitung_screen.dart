import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app/date_utils.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

class DataHitungScreen extends StatefulWidget {
  const DataHitungScreen({super.key});

  @override
  State<DataHitungScreen> createState() => _DataHitungScreenState();
}

class _DataHitungScreenState extends State<DataHitungScreen> {
  final db = DatabaseHelper.instance;
  final janjangC = TextEditingController();
  final janjangF = FocusNode();

  DateTime date = DateTime.now();
  List<Pemanen> pemanen = [];
  List<MasterBlok> blok = [];
  String? selectedPemanenNo;
  String? selectedBlok;
  List<DataHitung> history = [];
  Map<String, int> stats = const {
    'janjang': 0,
    'pemanen': 0,
    'input': 0,
  };

  bool loadingOptions = true;
  bool saving = false;
  int _optionsRequestId = 0;

  Pemanen? get selectedPemanen {
    final no = selectedPemanenNo;
    if (no == null) return null;
    for (final p in pemanen) {
      if (p.no == no) return p;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
    _init();
  }

  @override
  void dispose() {
    janjangC.dispose();
    janjangF.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // Data Hitung adalah pekerjaan operasional harian. Setiap kali layar
    // dibuka, mulai dari tanggal hari ini dan jangan membawa pilihan lama
    // dari transaksi/tanggal sebelumnya secara diam-diam.
    date = DateTime.now();
    selectedBlok = null;
    selectedPemanenNo = null;
    await _reloadOptions(resetSelection: true);
    await _refresh();
    if (mounted) setState(() {});
  }

  Future<void> _reloadOptions({bool resetSelection = false}) async {
    final requestId = ++_optionsRequestId;
    final key = dateKey(date);
    final previousBlok = resetSelection ? null : selectedBlok;
    final previousPemanen = resetSelection ? null : selectedPemanenNo;

    if (mounted) {
      setState(() => loadingOptions = true);
    }

    try {
      final blocks = await db.getBlokPanenTanggal(key);
      if (!mounted || requestId != _optionsRequestId || key != dateKey(date)) {
        return;
      }

      String? nextBlok = previousBlok;
      if (nextBlok != null && !blocks.any((b) => b.kode == nextBlok)) {
        nextBlok = null;
      }

      var people = <Pemanen>[];
      if (nextBlok != null) {
        people = await db.getPemanenBlokTanggal(key, nextBlok);
        if (!mounted || requestId != _optionsRequestId || key != dateKey(date)) {
          return;
        }
      }

      String? nextPemanen = previousPemanen;
      if (nextPemanen != null &&
          !people.any((p) => p.no == nextPemanen)) {
        nextPemanen = null;
      }

      setState(() {
        blok = blocks;
        selectedBlok = nextBlok;
        pemanen = people;
        selectedPemanenNo = nextPemanen;
        loadingOptions = false;
      });
    } catch (e) {
      if (!mounted || requestId != _optionsRequestId) return;
      setState(() {
        loadingOptions = false;
        blok = [];
        pemanen = [];
        selectedBlok = null;
        selectedPemanenNo = null;
      });
      _message('Gagal memuat blok/pemanen: $e');
    }
  }

  Future<void> _loadPemanenForBlock(String? kodeBlok) async {
    final requestId = ++_optionsRequestId;
    final key = dateKey(date);

    if (mounted) {
      setState(() {
        loadingOptions = true;
        selectedBlok = kodeBlok;
        selectedPemanenNo = null;
        pemanen = [];
      });
    }

    if (kodeBlok == null) {
      if (mounted && requestId == _optionsRequestId) {
        setState(() => loadingOptions = false);
      }
      return;
    }

    try {
      final data = await db.getPemanenBlokTanggal(key, kodeBlok);
      if (!mounted ||
          requestId != _optionsRequestId ||
          key != dateKey(date) ||
          selectedBlok != kodeBlok) {
        return;
      }

      setState(() {
        pemanen = data;
        selectedPemanenNo = null;
        loadingOptions = false;
      });
    } catch (e) {
      if (!mounted || requestId != _optionsRequestId) return;
      setState(() {
        pemanen = [];
        selectedPemanenNo = null;
        loadingOptions = false;
      });
      _message('Gagal memuat pemanen pada blok: $e');
    }
  }

  Future<void> _refresh() async {
    final key = dateKey(date);
    final h = await db.getDataHitungTanggal(key);
    final s = await db.dashboardTanggal(key);

    if (!mounted) return;
    setState(() {
      history = h;
      stats = s;
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

    setState(() {
      date = d;
      selectedBlok = null;
      selectedPemanenNo = null;
      blok = [];
      pemanen = [];
    });

    await _reloadOptions(resetSelection: true);
    await _refresh();
  }

  Future<bool> _confirmSave(Pemanen p, int j) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Konfirmasi Simpan'),
        content: Text(
          'Tanggal: ${displayDate(date)}\n'
          'Blok: ${selectedBlok ?? '-'}\n'
          'No Pemanen: ${p.no}\n'
          'Nama: ${p.nama}\n'
          'Janjang: $j\n\n'
          'Simpan data ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(c, true),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Simpan'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _save() async {
    if (saving) return;

    final p = selectedPemanen;
    final j = int.tryParse(janjangC.text.trim());

    if (blok.isEmpty) {
      _message('Belum ada blok panen untuk tanggal ini. Atur Absensi Per Blok terlebih dahulu.');
      return;
    }
    if (selectedBlok == null || selectedBlok!.isEmpty) {
      _message('Pilih blok terlebih dahulu.');
      return;
    }
    if (pemanen.isEmpty) {
      _message('Belum ada pemanen pada blok yang dipilih. Atur Absensi Per Blok terlebih dahulu.');
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

    setState(() => saving = true);

    try {
      final stillActive = await db.isPemanenAktifDiBlok(
        tanggal: dateKey(date),
        kodeBlok: selectedBlok!,
        noPemanen: p.no,
      );
      if (!stillActive) {
        await _reloadOptions(resetSelection: true);
        if (mounted) {
          _message(
            'Penempatan pemanen pada blok ini sudah berubah. Pilih ulang blok dan pemanen.',
          );
        }
        return;
      }

      final confirmed = await _confirmSave(p, j);
      if (!confirmed || !mounted) return;

      // Validasi sekali lagi tepat sebelum INSERT agar state lama tidak lolos
      // jika data penempatan berubah saat dialog konfirmasi terbuka.
      final stillActiveBeforeInsert = await db.isPemanenAktifDiBlok(
        tanggal: dateKey(date),
        kodeBlok: selectedBlok!,
        noPemanen: p.no,
      );
      if (!stillActiveBeforeInsert) {
        await _reloadOptions(resetSelection: true);
        if (mounted) {
          _message(
            'Absensi/blok berubah sebelum data disimpan. Silakan pilih ulang.',
          );
        }
        return;
      }

      await db.addDataHitung(
        DataHitung(
          tanggal: dateKey(date),
          jamInput: timeText(DateTime.now()),
          noPemanen: p.no,
          namaPemanen: p.nama,
          blok: selectedBlok!,
          janjang: j,
        ),
      );

      janjangC.clear();
      await _refresh();

      if (!mounted) return;
      _message('Data berhasil disimpan.');
      janjangF.requestFocus();
    } catch (e) {
      if (mounted) _message('Gagal menyimpan Data Hitung: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }


  Future<void> _edit(DataHitung d) async {
    final controller = TextEditingController(text: d.janjang.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit Data Hitung'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Jumlah Janjang'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(c, int.tryParse(controller.text)),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    // Controller dialog sengaja tidak dipakai lagi setelah route selesai.
    // Tidak melakukan dispose manual di sini untuk menghindari controller ter-dispose
    // ketika widget TextField masih dalam proses rebuild/animasi dialog.

    if (result == null || result <= 0 || d.id == null) return;

    await db.updateDataHitung(
      DataHitung(
        id: d.id,
        tanggal: d.tanggal,
        jamInput: d.jamInput,
        noPemanen: d.noPemanen,
        namaPemanen: d.namaPemanen,
        blok: d.blok,
        janjang: result,
      ),
    );
    await _refresh();
    _message('Data berhasil diperbarui.');
  }

  Future<void> _showItemMenu(DataHitung d) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(c, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Hapus'),
              onTap: () => Navigator.pop(c, 'hapus'),
            ),
          ],
        ),
      ),
    );

    if (action == 'edit') await _edit(d);
    if (action == 'hapus') await _delete(d);
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  Future<void> _delete(DataHitung d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Data?'),
        content: Text(
          '${d.noPemanen} - ${d.namaPemanen}\n'
          '${d.janjang} Janjang\n${d.jamInput}',
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

    if (ok == true && d.id != null) {
      await db.deleteDataHitung(d.id!);
      await _refresh();
    }
  }

  Widget _emptyAbsensiNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0D7A8)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF9A6A19), size: 20),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Absensi Per Blok belum diisi untuk tanggal ini. Isi absensi terlebih dahulu sebelum memasukkan hasil panen.',
              style: TextStyle(
                color: Color(0xFF6E511E),
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedPemanen;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF176B2C),
        foregroundColor: Colors.white,
        title: const Text('Data Hitung'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        children: [
          const Text(
            'INPUT HASIL PANEN',
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
          const SizedBox(height: 10),
          if (loadingOptions) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 8),
          ],

          DropdownButtonFormField<String>(
            isExpanded: true,
            value: selectedBlok != null && blok.any((b) => b.kode == selectedBlok)
                ? selectedBlok
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
                      b.kode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: loadingOptions || blok.isEmpty
                ? null
                : (v) => _loadPemanenForBlock(v),
            hint: Text(
              blok.isEmpty ? 'Absensi belum tersedia' : 'Pilih blok',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!loadingOptions && blok.isEmpty) ...[
            const SizedBox(height: 10),
            _emptyAbsensiNotice(),
          ],
          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            isExpanded: true,
            value: selectedPemanenNo != null &&
                    pemanen.any((p) => p.no == selectedPemanenNo)
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
            onChanged: loadingOptions || pemanen.isEmpty
                ? null
                : (v) {
                    setState(() => selectedPemanenNo = v);
                  },
            hint: Text(
              pemanen.isEmpty
                  ? (selectedBlok == null
                      ? 'Pilih blok terlebih dahulu'
                      : 'Belum ada pemanen')
                  : 'Pilih pemanen',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 10),

          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'No Pemanen',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            child: Text(selected?.no ?? '-'),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: janjangC,
            focusNode: janjangF,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
            onSubmitted: (_) {
              if (!saving && !loadingOptions) _save();
            },
            decoration: const InputDecoration(
              labelText: 'Jumlah Janjang',
              prefixIcon: Icon(Icons.park_outlined),
              suffixText: 'Janjang',
              hintText: 'Masukkan jumlah janjang',
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saving || loadingOptions ? null : _save,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                saving ? 'MENYIMPAN...' : 'SIMPAN DATA',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _Mini('Pemanen', '${stats['pemanen']} Orang'),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _Mini('Input', '${stats['input']} Kali'),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _Mini('Janjang', '${stats['janjang']}'),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Text(
            'DATA • ${displayDate(date).toUpperCase()}',
            style: TextStyle(
              color: Color(0xFF176B2C),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),

          if (history.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Center(
                  child: Text('Belum ada input pada tanggal ini.'),
                ),
              ),
            )
          else
            ...history.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(d.noPemanen)),
                    title: Text(
                      d.namaPemanen,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${d.blok} • ${d.jamInput} • ${d.janjang} Janjang',
                    ),
                    onLongPress: () => _showItemMenu(d),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;

  const _Mini(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
