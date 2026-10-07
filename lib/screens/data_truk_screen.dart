import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/date_utils.dart';
import '../database/database_helper.dart';
import '../models/models.dart';

class DataTrukScreen extends StatefulWidget {
  final int refreshToken;

  const DataTrukScreen({
    super.key,
    this.refreshToken = 0,
  });

  @override
  State<DataTrukScreen> createState() => _DataTrukScreenState();
}

class _DataTrukScreenState extends State<DataTrukScreen> {
  static const green = Color(0xFF176B2C);

  final db = DatabaseHelper.instance;
  final janjangC = TextEditingController();
  final janjangF = FocusNode();

  DateTime date = DateTime.now();

  List<MasterTruk> truks = [];
  List<MasterBlok> bloks = [];
  List<Pemanen> pemanenList = [];

  String? selectedTrukName;
  String? selectedBlokKode;
  String? selectedPemanenNo;

  List<DataTruk> rows = [];

  bool saving = false;
  int _mastersRequestId = 0;
  int _pemanenRequestId = 0;


  MasterTruk? get selectedTruk {
    final name = selectedTrukName;
    if (name == null) return null;
    for (final t in truks) {
      if (t.nama == name) return t;
    }
    return null;
  }

  MasterBlok? get selectedBlok {
    final kode = selectedBlokKode;
    if (kode == null) return null;
    for (final b in bloks) {
      if (b.kode == kode) return b;
    }
    return null;
  }

  Pemanen? get selectedPemanen {
    final no = selectedPemanenNo;
    if (no == null) return null;
    for (final p in pemanenList) {
      if (p.no == no) return p;
    }
    return null;
  }

  Map<String, List<DataTruk>> get grouped {
    final map = <String, List<DataTruk>>{};
    for (final r in rows) {
      map.putIfAbsent(r.blok, () => []).add(r);
    }
    return map;
  }

  int get total => rows.fold(0, (sum, item) => sum + item.janjang);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
    _init();
  }

  @override
  void didUpdateWidget(covariant DataTrukScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _reloadFromTab();
    }
  }

  Future<void> _reloadFromTab() async {
    await _loadMasters();
    await _refresh();
  }

  @override
  void dispose() {
    janjangC.dispose();
    janjangF.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final lastDate = await db.getSetting('last_truk_date');
    if (lastDate != null) {
      try {
        date = parseDateKey(lastDate);
      } catch (_) {}
    }

    await _loadMasters();

    final lastTruk = await db.getSetting('last_truk');
    final lastBlok = await db.getSetting('last_blok');
    final lastPemanenNo = await db.getSetting('last_truk_pemanen_no');

    if (lastTruk != null && truks.any((t) => t.nama == lastTruk)) {
      selectedTrukName = lastTruk;
    }

    if (lastBlok != null && bloks.any((b) => b.kode == lastBlok)) {
      selectedBlokKode = lastBlok;
      await _loadPemanenForSelectedBlok();
    }

    if (lastPemanenNo != null &&
        pemanenList.any((p) => p.no == lastPemanenNo)) {
      selectedPemanenNo = lastPemanenNo;
    }

    await _refresh();
    if (mounted) setState(() {});
  }

  Future<void> _loadMasters() async {
    final requestId = ++_mastersRequestId;
    final key = dateKey(date);
    final newTruks = await db.getMasterTruk();
    final newBloks = await db.getBlokPanenTanggal(key);

    if (!mounted || requestId != _mastersRequestId || key != dateKey(date)) {
      return;
    }

    String? nextTruk = selectedTrukName;
    String? nextBlok = selectedBlokKode;

    if (nextTruk != null && !newTruks.any((t) => t.nama == nextTruk)) {
      nextTruk = null;
    }

    if (nextBlok != null && !newBloks.any((b) => b.kode == nextBlok)) {
      nextBlok = null;
    }

    final newPemanen = nextBlok == null
        ? <Pemanen>[]
        : await db.getPemanenBlokTanggal(key, nextBlok);

    if (!mounted || requestId != _mastersRequestId || key != dateKey(date)) {
      return;
    }

    String? nextPemanen = selectedPemanenNo;
    if (nextPemanen != null && !newPemanen.any((p) => p.no == nextPemanen)) {
      nextPemanen = null;
    }

    setState(() {
      truks = newTruks;
      bloks = newBloks;
      pemanenList = newPemanen;
      selectedTrukName = nextTruk;
      selectedBlokKode = nextBlok;
      selectedPemanenNo = nextPemanen;
    });
  }

  Future<void> _loadPemanenForSelectedBlok() async {
    final requestId = ++_pemanenRequestId;
    final kode = selectedBlokKode;
    final key = dateKey(date);
    final list = kode == null
        ? <Pemanen>[]
        : await db.getPemanenBlokTanggal(key, kode);

    if (!mounted ||
        requestId != _pemanenRequestId ||
        key != dateKey(date) ||
        selectedBlokKode != kode) {
      return;
    }

    String? next = selectedPemanenNo;
    if (next != null && !list.any((p) => p.no == next)) {
      next = null;
    }

    setState(() {
      pemanenList = list;
      selectedPemanenNo = next;
    });
  }

  Future<void> _refresh() async {
    final t = selectedTruk;

    if (t == null) {
      if (mounted) setState(() => rows = []);
      return;
    }

    final data = await db.getDataTrukByTanggalTruk(
      dateKey(date),
      t.nama,
    );

    if (mounted) {
      setState(() => rows = data);
    }
  }

  Future<void> _chooseDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (d == null) return;

    setState(() => date = d);
    await db.setSetting('last_truk_date', dateKey(d));
    await _loadMasters();
    await _refresh();
  }

  Future<bool> _confirmSave(
    MasterTruk t,
    MasterBlok b,
    Pemanen p,
    int j,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Konfirmasi Simpan Muatan'),
        content: Text(
          'Tanggal: ${displayDate(date)}\n'
          'Truk: ${t.nama}\n'
          'Blok: ${b.kode}\n'
          'Pemanen: ${p.no} • ${p.nama}\n'
          'Janjang: $j\n\n'
          'Tambahkan muatan ini?',
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

    return result == true;
  }

  Future<void> _save() async {
    if (saving) return;

    final t = selectedTruk;
    final b = selectedBlok;
    final p = selectedPemanen;
    final j = int.tryParse(janjangC.text.trim());

    if (bloks.isEmpty) {
      _message('Belum ada blok panen untuk tanggal ini. Atur Absensi Per Blok terlebih dahulu.');
      return;
    }
    if (pemanenList.isEmpty) {
      _message('Belum ada pemanen pada blok yang dipilih. Atur Absensi Per Blok terlebih dahulu.');
      return;
    }
    if (t == null || b == null || p == null || j == null || j <= 0) {
      _message('Lengkapi truk, blok, pemanen dan janjang.');
      return;
    }

    setState(() => saving = true);
    try {
      final stillActive = await db.isPemanenAktifDiBlok(
        tanggal: dateKey(date),
        kodeBlok: b.kode,
        noPemanen: p.no,
      );
      if (!stillActive) {
        await _loadMasters();
        if (mounted) {
          _message(
            'Penempatan pemanen pada blok ini sudah berubah. Pilih ulang blok dan pemanen.',
          );
        }
        return;
      }

      final confirmed = await _confirmSave(t, b, p, j);
      if (!confirmed || !mounted) return;

      final stillActiveBeforeInsert = await db.isPemanenAktifDiBlok(
        tanggal: dateKey(date),
        kodeBlok: b.kode,
        noPemanen: p.no,
      );
      if (!stillActiveBeforeInsert) {
        await _loadMasters();
        if (mounted) {
          _message('Absensi/blok berubah sebelum muatan disimpan. Pilih ulang.');
        }
        return;
      }

      await db.addDataTruk(
        DataTruk(
          tanggal: dateKey(date),
          jamInput: timeText(DateTime.now()),
          namaTruk: t.nama,
          blok: b.kode,
          noPemanen: p.no,
          pemanen: p.nama,
          janjang: j,
        ),
      );

      await db.setSetting('last_truk_date', dateKey(date));
      await db.setSetting('last_truk', t.nama);
      await db.setSetting('last_blok', b.kode);
      await db.setSetting('last_truk_pemanen_no', p.no);

      janjangC.clear();
      await _refresh();

      if (!mounted) return;
      _message('Muatan berhasil disimpan.');
      janjangF.requestFocus();
    } catch (e) {
      if (mounted) _message('Gagal menyimpan muatan: $e');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }


  Future<void> _edit(DataTruk d) async {
    if (d.id == null) return;

    final value = await showDialog<int>(
      context: context,
      builder: (_) => _EditMuatanDialog(initialValue: d.janjang),
    );

    if (value == null || value <= 0 || !mounted) return;

    try {
      final updated = await db.updateDataTruk(
        DataTruk(
          id: d.id,
          tanggal: d.tanggal,
          jamInput: d.jamInput,
          namaTruk: d.namaTruk,
          blok: d.blok,
          noPemanen: d.noPemanen,
          pemanen: d.pemanen,
          janjang: value,
        ),
      );

      if (updated == 0) {
        _message('Data muatan tidak ditemukan.');
        return;
      }

      await _refresh();
      if (mounted) _message('Muatan berhasil diperbarui.');
    } catch (e) {
      if (mounted) _message('Gagal menyimpan perubahan muatan: $e');
    }
  }

  Future<void> _showItemMenu(DataTruk d) async {
    final a=await showModalBottomSheet<String>(context:context,builder:(c)=>SafeArea(child:Wrap(children:[ListTile(leading:const Icon(Icons.edit),title:const Text('Edit Muatan'),onTap:()=>Navigator.pop(c,'edit')),ListTile(leading:const Icon(Icons.delete),title:const Text('Hapus Muatan'),onTap:()=>Navigator.pop(c,'hapus'))])));
    if(a=='edit')await _edit(d); if(a=='hapus')await _delete(d);
  }

  Future<void> _delete(DataTruk d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Muatan?'),
        content: Text(
          '${d.blok} • ${_pemanenText(d)}\n${d.janjang} Janjang',
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
      await db.deleteDataTruk(d.id!);
      await _refresh();
    }
  }

  String _pemanenText(DataTruk item) {
    final no = item.noPemanen.trim();
    if (no.isEmpty) return item.pemanen;
    return '$no • ${item.pemanen}';
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = selectedTruk;
    final metrics = _DataTrukMetrics.fromWidth(MediaQuery.sizeOf(context).width);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: const Color(0xFFF4F7F3),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7F3),
        body: RefreshIndicator(
          onRefresh: _refresh,
          color: green,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _DataTrukHeader(
                  compact: metrics.compact,
                  onBack: () => Navigator.maybePop(context),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Transform.translate(
                      offset: const Offset(0, -12),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          metrics.pagePadding,
                          0,
                          metrics.pagePadding,
                          28,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _InputPanel(
                              compact: metrics.compact,
                              date: date,
                              chooseDate: _chooseDate,
                              truks: truks,
                              bloks: bloks,
                              pemanenList: pemanenList,
                              selectedTrukName: selectedTrukName,
                              selectedBlokKode: selectedBlokKode,
                              selectedPemanenNo: selectedPemanenNo,
                              onTrukChanged: (v) async {
                                setState(() => selectedTrukName = v);
                                await _refresh();
                              },
                              onBlokChanged: (v) async {
                                setState(() {
                                  selectedBlokKode = v;
                                  selectedPemanenNo = null;
                                });
                                await _loadPemanenForSelectedBlok();
                              },
                              onPemanenChanged: (v) {
                                setState(() => selectedPemanenNo = v);
                              },
                              janjangC: janjangC,
                              janjangF: janjangF,
                              save: _save,
                              saving: saving,
                            ),
                            SizedBox(height: metrics.sectionGap),
                            if (t != null)
                              _SummaryPanel(
                                compact: metrics.compact,
                                namaTruk: t.nama,
                                date: date,
                                total: total,
                                grouped: grouped,
                                onLongPress: _showItemMenu,
                              ),
                          ],
                        ),
                      ),
                    ),
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

class _DataTrukMetrics {
  final bool compact;
  final double pagePadding;
  final double sectionGap;

  const _DataTrukMetrics({
    required this.compact,
    required this.pagePadding,
    required this.sectionGap,
  });

  factory _DataTrukMetrics.fromWidth(double width) {
    final compact = width < 390;
    return _DataTrukMetrics(
      compact: compact,
      pagePadding: width >= 600 ? 24 : (compact ? 14 : 16),
      sectionGap: compact ? 14 : 18,
    );
  }
}

class _DataTrukHeader extends StatelessWidget {
  final bool compact;
  final VoidCallback onBack;

  const _DataTrukHeader({
    required this.compact,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final topInset = MediaQuery.paddingOf(context).top;
    final visualHeight = (width * 0.30).clamp(116.0, 140.0);
    final headerHeight = topInset + visualHeight;

    return SizedBox(
      height: headerHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/headers/data_truk_header_user.png',
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFF075D2E).withValues(alpha: .92),
                  const Color(0xFF075D2E).withValues(alpha: .62),
                  Colors.transparent,
                ],
                stops: const [0, .48, .88],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 18 : 22,
              topInset + 10,
              compact ? 18 : 22,
              20,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Material(
                  color: Colors.white.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: onBack,
                    child: SizedBox(
                      width: compact ? 48 : 52,
                      height: compact ? 48 : 52,
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 29,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: compact ? 14 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: compact ? 3 : 4),
                      Text(
                        'Data Truk',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 27 : 30,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Catat dan kelola muatan truk harian',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .92),
                          fontSize: compact ? 11.8 : 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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

class _InputPanel extends StatelessWidget {
  static const green = Color(0xFF176B2C);
  static const border = Color(0xFFE1E7E1);

  final bool compact;
  final DateTime date;
  final VoidCallback chooseDate;
  final List<MasterTruk> truks;
  final List<MasterBlok> bloks;
  final List<Pemanen> pemanenList;
  final String? selectedTrukName;
  final String? selectedBlokKode;
  final String? selectedPemanenNo;
  final ValueChanged<String?> onTrukChanged;
  final ValueChanged<String?> onBlokChanged;
  final ValueChanged<String?> onPemanenChanged;
  final TextEditingController janjangC;
  final FocusNode janjangF;
  final VoidCallback save;
  final bool saving;

  const _InputPanel({
    required this.compact,
    required this.date,
    required this.chooseDate,
    required this.truks,
    required this.bloks,
    required this.pemanenList,
    required this.selectedTrukName,
    required this.selectedBlokKode,
    required this.selectedPemanenNo,
    required this.onTrukChanged,
    required this.onBlokChanged,
    required this.onPemanenChanged,
    required this.janjangC,
    required this.janjangF,
    required this.save,
    required this.saving,
  });

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Padding(
        padding: const EdgeInsets.all(7),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF6EC),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: green, size: 23),
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 56, minHeight: 56),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 12 : 13,
      ),
      labelStyle: const TextStyle(
        color: Color(0xFF657066),
        fontWeight: FontWeight.w500,
      ),
      hintStyle: const TextStyle(color: Color(0xFF949D96)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: border, width: 1.1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: green, width: 1.7),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: border, width: 1.1),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: border),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFEFD),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .045),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 52 : 56,
                height: compact ? 52 : 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF6EC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.eco_rounded, color: green, size: 28),
              ),
              SizedBox(width: compact ? 12 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INPUT DATA TRUK',
                      style: TextStyle(
                        color: const Color(0xFF0B5F30),
                        fontSize: compact ? 18.5 : 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Lengkapi informasi truk dan muatan',
                      style: TextStyle(
                        color: const Color(0xFF7B8580),
                        fontSize: compact ? 10.8 : 12.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 14 : 16),
          InkWell(
            onTap: chooseDate,
            borderRadius: BorderRadius.circular(18),
            child: InputDecorator(
              decoration: _decoration(
                label: 'Tanggal',
                icon: Icons.calendar_month_rounded,
                suffix: const Icon(Icons.calendar_month_outlined),
              ),
              child: Text(
                displayDate(date),
                style: TextStyle(
                  color: const Color(0xFF151A16),
                  fontSize: compact ? 15 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(height: compact ? 10 : 11),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: selectedTrukName != null && truks.any((x) => x.nama == selectedTrukName)
                ? selectedTrukName
                : null,
            decoration: _decoration(
              label: 'Nama Truk',
              icon: Icons.local_shipping_rounded,
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            items: truks
                .map((x) => DropdownMenuItem<String>(
                      value: x.nama,
                      child: Text(x.nama, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: onTrukChanged,
          ),
          SizedBox(height: compact ? 10 : 11),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: selectedBlokKode != null && bloks.any((x) => x.kode == selectedBlokKode)
                ? selectedBlokKode
                : null,
            decoration: _decoration(
              label: 'Blok',
              icon: Icons.location_on_rounded,
              hint: bloks.isEmpty ? 'Absensi belum tersedia' : 'Pilih blok',
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            items: bloks
                .map((x) => DropdownMenuItem<String>(
                      value: x.kode,
                      child: Text(x.kode, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: bloks.isEmpty ? null : onBlokChanged,
          ),
          SizedBox(height: compact ? 10 : 11),
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: selectedPemanenNo != null && pemanenList.any((p) => p.no == selectedPemanenNo)
                ? selectedPemanenNo
                : null,
            decoration: _decoration(
              label: 'Pemanen',
              icon: Icons.groups_rounded,
              hint: pemanenList.isEmpty
                  ? (selectedBlokKode == null ? 'Pilih blok terlebih dahulu' : 'Belum ada pemanen')
                  : 'Pilih pemanen',
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            items: pemanenList
                .map((p) => DropdownMenuItem<String>(
                      value: p.no,
                      child: Text('${p.no} • ${p.nama}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: pemanenList.isEmpty ? null : onPemanenChanged,
          ),
          SizedBox(height: compact ? 10 : 11),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: green, width: 1.6),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF6EC),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(Icons.eco_rounded, color: green, size: 23),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Janjang',
                          style: TextStyle(
                            color: Color(0xFF657066),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 1),
                        TextField(
                          controller: janjangC,
                          focusNode: janjangF,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onSubmitted: (_) => save(),
                          style: TextStyle(
                            fontSize: compact ? 15 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Masukkan jumlah janjang',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF6EC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Janjang',
                    style: TextStyle(
                      color: Color(0xFF526057),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 13 : 15),
          SizedBox(
            height: compact ? 56 : 60,
            child: FilledButton(
              onPressed: saving ? null : save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D7138),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: saving
                        ? const Padding(
                            padding: EdgeInsets.all(9),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: green,
                            ),
                          )
                        : const Icon(Icons.add_rounded, color: green, size: 25),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    saving ? 'MENYIMPAN...' : 'TAMBAH MUATAN',
                    style: TextStyle(
                      fontSize: compact ? 15 : 16.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditMuatanDialog extends StatefulWidget {
  final int initialValue;

  const _EditMuatanDialog({required this.initialValue});

  @override
  State<_EditMuatanDialog> createState() => _EditMuatanDialogState();
}

class _EditMuatanDialogState extends State<_EditMuatanDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Muatan'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Janjang', suffixText: 'Janjang'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: () {
            final value = int.tryParse(controller.text.trim());
            if (value == null || value <= 0) return;
            Navigator.pop(context, value);
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final bool compact;
  final String namaTruk;
  final DateTime date;
  final int total;
  final Map<String, List<DataTruk>> grouped;
  final ValueChanged<DataTruk> onLongPress;

  const _SummaryPanel({
    required this.compact,
    required this.namaTruk,
    required this.date,
    required this.total,
    required this.grouped,
    required this.onLongPress,
  });

  static const ink = Color(0xFF172119);
  static const muted = Color(0xFF748078);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, color: Color(0xFFDDE5DD)),
        SizedBox(height: compact ? 16 : 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final tight = constraints.maxWidth < 350;
            if (tight) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'REKAP MUATAN TRUK',
                    style: TextStyle(
                      color: ink,
                      fontSize: compact ? 18 : 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Daftar muatan untuk truk dan tanggal ini',
                    style: TextStyle(color: muted, fontSize: compact ? 10.5 : 12),
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: Text(
                    'REKAP MUATAN TRUK',
                    style: TextStyle(
                      color: ink,
                      fontSize: compact ? 18 : 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  'Daftar muatan untuk truk dan tanggal ini',
                  style: TextStyle(color: muted, fontSize: compact ? 10.5 : 12),
                ),
              ],
            );
          },
        ),
        SizedBox(height: compact ? 12 : 14),
        _TruckSummaryCard(
          compact: compact,
          namaTruk: namaTruk,
          date: date,
          total: total,
        ),
        SizedBox(height: compact ? 12 : 14),
        ...grouped.entries.map((entry) {
          final subtotal = entry.value.fold(0, (sum, item) => sum + item.janjang);
          return Padding(
            padding: EdgeInsets.only(bottom: compact ? 12 : 14),
            child: _BlockMuatanCard(
              compact: compact,
              block: entry.key,
              subtotal: subtotal,
              items: entry.value,
              onItemMenu: onLongPress,
            ),
          );
        }),
      ],
    );
  }
}

class _TruckSummaryCard extends StatelessWidget {
  final bool compact;
  final String namaTruk;
  final DateTime date;
  final int total;

  const _TruckSummaryCard({
    required this.compact,
    required this.namaTruk,
    required this.date,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 18,
        vertical: compact ? 16 : 18,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF9EE), Color(0xFFE2F4E3)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDDEDDD)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 54 : 58,
            height: compact ? 54 : 58,
            decoration: const BoxDecoration(
              color: Color(0xFFD9EFDB),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF0C7338), size: 29),
          ),
          SizedBox(width: compact ? 14 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  namaTruk,
                  style: TextStyle(
                    color: const Color(0xFF112716),
                    fontSize: compact ? 17.5 : 19.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  displayDate(date),
                  style: TextStyle(
                    color: const Color(0xFF536058),
                    fontSize: compact ? 12.4 : 13.6,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 56, color: const Color(0xFFC9DFC8)),
          SizedBox(width: compact ? 14 : 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Muatan',
                style: TextStyle(
                  color: const Color(0xFF5B9166),
                  fontSize: compact ? 12 : 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$total Janjang',
                style: TextStyle(
                  color: const Color(0xFF0C7338),
                  fontSize: compact ? 20 : 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BlockMuatanCard extends StatelessWidget {
  final bool compact;
  final String block;
  final int subtotal;
  final List<DataTruk> items;
  final ValueChanged<DataTruk> onItemMenu;

  const _BlockMuatanCard({
    required this.compact,
    required this.block,
    required this.subtotal,
    required this.items,
    required this.onItemMenu,
  });

  String _pemanen(DataTruk item) {
    final no = item.noPemanen.trim();
    return no.isEmpty ? item.pemanen : '$no • ${item.pemanen}';
  }

  Widget _itemRow(DataTruk item) {
    return Material(
      color: const Color(0xFFF8FBF8),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onItemMenu(item),
        onLongPress: () => onItemMenu(item),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 12 : 14,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Color(0xFFE4F2E5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: Color(0xFF0C7338),
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pemanen(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF151A16),
                        fontSize: compact ? 15 : 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 17,
                          color: Color(0xFF7A847D),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          item.jamInput,
                          style: TextStyle(
                            color: const Color(0xFF7A847D),
                            fontSize: compact ? 11.8 : 12.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: const Color(0xFFD9E1D8),
              ),
              const SizedBox(width: 10),
              Container(
                constraints: const BoxConstraints(minWidth: 66),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6E8),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  '${item.janjang}',
                  style: TextStyle(
                    color: const Color(0xFF0C7338),
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8ECE7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF6EC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF0C7338),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Blok $block',
                  style: TextStyle(
                    color: const Color(0xFF131A14),
                    fontSize: compact ? 16 : 17.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$subtotal Janjang',
                style: TextStyle(
                  color: const Color(0xFF0C7338),
                  fontSize: compact ? 14.5 : 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              PopupMenuButton<int>(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF6C766F)),
                onSelected: (index) {
                  if (index >= 0 && index < items.length) {
                    onItemMenu(items[index]);
                  }
                },
                itemBuilder: (_) => [
                  for (var i = 0; i < items.length; i++)
                    PopupMenuItem<int>(
                      value: i,
                      child: Text('${_pemanen(items[i])} • ${items[i].janjang} Janjang'),
                    ),
                ],
              ),
            ],
          ),
          if (items.isNotEmpty) const SizedBox(height: 10),
          for (var i = 0; i < items.length; i++) ...[
            _itemRow(items[i]),
            if (i != items.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
