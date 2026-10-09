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
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Transform.translate(
                      // Keep the form below the header instead of pulling it upward.
                      // This gives the INPUT DATA TRUK title the same breathing room
                      // as the visual reference.
                      offset: Offset.zero,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          metrics.pagePadding,
                          metrics.compact ? 10 : 12,
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
                              formEnabled: truks.isNotEmpty && bloks.isNotEmpty,
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
                              )
                            else
                              _EmptyRekapPanel(
                                compact: metrics.compact,
                                noTruckMaster: truks.isEmpty,
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
      pagePadding: width >= 600 ? 22 : (compact ? 12 : 14),
      sectionGap: compact ? 7 : 8,
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
    // Keep the artwork close to its native 2048x347 proportion. The status bar
    // is included in the green header so no pale strip appears above it.
    final visualHeight = (width * 0.148).clamp(56.0, 68.0);
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
            alignment: Alignment.center,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFF075D2E).withValues(alpha: .94),
                  const Color(0xFF075D2E).withValues(alpha: .62),
                  const Color(0xFF075D2E).withValues(alpha: .08),
                ],
                stops: const [0, .46, .86],
              ),
            ),
          ),
          Positioned(
            left: compact ? 16 : 18,
            top: topInset + 6,
            child: Material(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(7),
              child: InkWell(
                borderRadius: BorderRadius.circular(7),
                onTap: onBack,
                child: SizedBox(
                  width: compact ? 34 : 36,
                  height: compact ? 34 : 36,
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: compact ? 61 : 66,
            right: 16,
            top: topInset + 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Truk',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 20.5 : 22.0,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Catat dan kelola muatan truk harian',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .94),
                    fontSize: compact ? 9.5 : 10.1,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
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
  static const muted = Color(0xFF6F7972);

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
  final bool formEnabled;

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
    required this.formEnabled,
  });

  Widget _iconBox(IconData icon) {
    final size = compact ? 31.0 : 32.5;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6EC),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, color: green, size: compact ? 17.5 : 18.5),
    );
  }

  Widget _fieldFrame({
    required String label,
    required IconData icon,
    required Widget child,
    Widget? trailing,
    bool active = false,
    VoidCallback? onTap,
  }) {
    final radius = BorderRadius.circular(8);
    final labelSize = compact ? 9.2 : 9.7;
    final labelOffset = compact ? 5.0 : 5.3;
    final fieldHeight = compact ? 47.0 : 49.0;

    final frame = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: fieldHeight,
          margin: EdgeInsets.only(top: labelOffset),
          padding: EdgeInsets.fromLTRB(
            compact ? 6 : 6.5,
            0,
            compact ? 8 : 9,
            0,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: radius,
            border: Border.all(
              color: active ? green : border,
              width: active ? 1.45 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _iconBox(icon),
              SizedBox(width: compact ? 8 : 9),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: child,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                Align(
                  alignment: Alignment.center,
                  child: trailing,
                ),
              ],
            ],
          ),
        ),
        Positioned(
          left: compact ? 17 : 18,
          top: 0,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: muted,
                fontSize: labelSize,
                height: 1.05,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );

    if (onTap == null) return frame;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: frame,
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?>? onChanged,
  }) {
    return _fieldFrame(
      label: label,
      icon: icon,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          isDense: true,
          value: value,
          hint: Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF959D97),
              fontSize: compact ? 12.4 : 13.2,
              fontWeight: FontWeight.w500,
            ),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF606761),
            size: 19,
          ),
          style: TextStyle(
            color: const Color(0xFF151A16),
            fontSize: compact ? 13.2 : 13.8,
            fontWeight: FontWeight.w600,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trukValue = selectedTrukName != null &&
            truks.any((x) => x.nama == selectedTrukName)
        ? selectedTrukName
        : null;
    final blokValue = selectedBlokKode != null &&
            bloks.any((x) => x.kode == selectedBlokKode)
        ? selectedBlokKode
        : null;
    final pemanenValue = selectedPemanenNo != null &&
            pemanenList.any((p) => p.no == selectedPemanenNo)
        ? selectedPemanenNo
        : null;

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 12 : 13,
        compact ? 16 : 17,
        compact ? 12 : 13,
        compact ? 12 : 13,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFEFD),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .035),
            blurRadius: 13,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 34 : 36,
                height: compact ? 34 : 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF6EC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.eco_rounded, color: green, size: 18),
              ),
              SizedBox(width: compact ? 9 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INPUT DATA TRUK',
                      style: TextStyle(
                        color: const Color(0xFF0B5F30),
                        fontSize: compact ? 15.2 : 16.2,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Lengkapi informasi truk dan muatan',
                      style: TextStyle(
                        color: const Color(0xFF7B8580),
                        fontSize: compact ? 9.0 : 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 9),
          _fieldFrame(
            label: 'Tanggal',
            icon: Icons.calendar_month_rounded,
            onTap: chooseDate,
            trailing: const Icon(
              Icons.calendar_month_outlined,
              color: Color(0xFF4E5650),
              size: 18,
            ),
            child: Text(
              displayDate(date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF151A16),
                fontSize: compact ? 13.2 : 13.8,
                height: 1.05,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: compact ? 6 : 7),
          _dropdownField(
            label: 'Nama Truk',
            icon: Icons.local_shipping_rounded,
            value: trukValue,
            hint: truks.isEmpty ? 'Belum ada data truk' : 'Pilih truk',
            items: truks
                .map(
                  (x) => DropdownMenuItem<String>(
                    value: x.nama,
                    child: Text(
                      x.nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: truks.isEmpty ? null : onTrukChanged,
          ),
          SizedBox(height: compact ? 6 : 7),
          _dropdownField(
            label: 'Blok',
            icon: Icons.location_on_rounded,
            value: blokValue,
            hint: bloks.isEmpty ? 'Absensi belum di atur' : 'Pilih blok',
            items: bloks
                .map(
                  (x) => DropdownMenuItem<String>(
                    value: x.kode,
                    child: Text(
                      x.kode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: bloks.isEmpty ? null : onBlokChanged,
          ),
          SizedBox(height: compact ? 6 : 7),
          _dropdownField(
            label: 'Pemanen',
            icon: Icons.groups_rounded,
            value: pemanenValue,
            hint: pemanenList.isEmpty
                ? (selectedBlokKode == null
                    ? 'Pilih blok terlebih dahulu'
                    : 'Belum ada pemanen')
                : 'Pilih pemanen',
            items: pemanenList
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
            onChanged: pemanenList.isEmpty ? null : onPemanenChanged,
          ),
          SizedBox(height: compact ? 6 : 7),
          _fieldFrame(
            label: 'Janjang',
            icon: Icons.eco_rounded,
            active: true,
            trailing: Container(
              width: compact ? 48 : 52,
              height: compact ? 28 : 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF6EC),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'JJG',
                style: TextStyle(
                  color: const Color(0xFF526057),
                  fontSize: compact ? 10.8 : 11.4,
                  height: 1.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            child: TextField(
              controller: janjangC,
              focusNode: janjangF,
              textAlignVertical: TextAlignVertical.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => save(),
              style: TextStyle(
                fontSize: compact ? 13.0 : 13.6,
                height: 1.05,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Masukkan jumlah janjang',
                hintStyle: TextStyle(
                  color: const Color(0xFF98A09A),
                  fontSize: compact ? 11.8 : 12.5,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          SizedBox(height: compact ? 8 : 9),
          SizedBox(
            height: compact ? 44 : 46,
            child: FilledButton(
              onPressed: saving || !formEnabled ? null : save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0D7138),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFDDE9DF),
                disabledForegroundColor: const Color(0xFF78907D),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: formEnabled ? 1.5 : 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: compact ? 26 : 27,
                    height: compact ? 26 : 27,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: formEnabled ? 1 : .72),
                      shape: BoxShape.circle,
                    ),
                    child: saving
                        ? const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: green,
                            ),
                          )
                        : Icon(
                            Icons.add_rounded,
                            color: formEnabled ? green : const Color(0xFF78907D),
                            size: 16,
                          ),
                  ),
                  SizedBox(width: compact ? 10 : 11),
                  Text(
                    saving ? 'MENYIMPAN...' : 'TAMBAH MUATAN',
                    style: TextStyle(
                      fontSize: compact ? 12.7 : 13.4,
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
        decoration: const InputDecoration(labelText: 'Janjang', suffixText: 'JJG'),
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
        SizedBox(height: compact ? 10 : 11),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 10,
              child: Text(
                'MUATAN TRUK',
                maxLines: 1,
                style: TextStyle(
                  color: ink,
                  fontSize: compact ? 15.0 : 15.8,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 7 : 8),
        _TruckSummaryCard(
          compact: compact,
          namaTruk: namaTruk,
          date: date,
          total: total,
        ),
        SizedBox(height: compact ? 7 : 8),
        if (grouped.isEmpty)
          _CompactEmptyCard(
            compact: compact,
            icon: Icons.local_shipping_outlined,
            title: 'Belum ada muatan',
            subtitle: 'Muatan yang ditambahkan akan tampil di sini.',
          ),
        ...grouped.entries.map((entry) {
          final subtotal = entry.value.fold(0, (sum, item) => sum + item.janjang);
          return Padding(
            padding: EdgeInsets.only(bottom: compact ? 9 : 10),
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

class _EmptyRekapPanel extends StatelessWidget {
  final bool compact;
  final bool noTruckMaster;

  const _EmptyRekapPanel({
    required this.compact,
    required this.noTruckMaster,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, color: Color(0xFFDDE5DD)),
        SizedBox(height: compact ? 10 : 11),
        Row(
          children: [
            Expanded(
              child: Text(
                'MUATAN TRUK',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF172119),
                  fontSize: compact ? 15.0 : 15.8,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 7 : 8),
        _CompactEmptyCard(
          compact: compact,
          icon: noTruckMaster
              ? Icons.local_shipping_outlined
              : Icons.receipt_long_outlined,
          title: noTruckMaster ? 'Master truk belum tersedia' : 'Pilih truk terlebih dahulu',
          subtitle: noTruckMaster
              ? 'Tambahkan Master Truk agar pencatatan muatan dapat digunakan.'
              : 'Pilih truk untuk menampilkan rekap muatan pada tanggal ini.',
        ),
      ],
    );
  }
}

class _CompactEmptyCard extends StatelessWidget {
  final bool compact;
  final IconData icon;
  final String title;
  final String subtitle;

  const _CompactEmptyCard({
    required this.compact,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 11 : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E8E1), width: .9),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 34 : 36,
            height: compact ? 34 : 36,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF6EC),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFF3F7950),
              size: compact ? 18 : 19,
            ),
          ),
          SizedBox(width: compact ? 10 : 11),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF253128),
                    fontSize: compact ? 11.7 : 12.3,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF7B857E),
                    fontSize: compact ? 9.2 : 9.8,
                    height: 1.25,
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
        horizontal: compact ? 10 : 11,
        vertical: compact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF9EE), Color(0xFFE3F5E4)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCECDC), width: .9),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 36 : 38,
            height: compact ? 36 : 38,
            decoration: const BoxDecoration(
              color: Color(0xFFD9EFDB),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_shipping_rounded,
              color: const Color(0xFF0C7338),
              size: compact ? 20 : 21,
            ),
          ),
          SizedBox(width: compact ? 8 : 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  namaTruk,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF112716),
                    fontSize: compact ? 14.2 : 15.0,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  displayDate(date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF536058),
                    fontSize: compact ? 10.1 : 10.7,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: compact ? 32 : 34, color: const Color(0xFFC9DFC8)),
          SizedBox(width: compact ? 8 : 9),
          Container(
            width: compact ? 23 : 25,
            height: compact ? 23 : 25,
            decoration: BoxDecoration(
              color: const Color(0xFFD7F0D9),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Icon(
              Icons.view_agenda_rounded,
              color: const Color(0xFF149447),
              size: compact ? 13 : 14,
            ),
          ),
          SizedBox(width: compact ? 7 : 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total Muatan',
                  maxLines: 1,
                  style: TextStyle(
                    color: const Color(0xFF5B9166),
                    fontSize: compact ? 9.2 : 9.8,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 1.5),
                Text(
                  '$total Janjang',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF0C7338),
                    fontSize: compact ? 15.3 : 16.5,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
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
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => onItemMenu(item),
        onLongPress: () => onItemMenu(item),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 9,
            vertical: compact ? 6 : 6.5,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 29 : 31,
                height: compact ? 29 : 31,
                decoration: const BoxDecoration(
                  color: Color(0xFFE4F2E5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: const Color(0xFF0C7338),
                  size: compact ? 17 : 18,
                ),
              ),
              SizedBox(width: compact ? 8 : 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _pemanen(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF151A16),
                        fontSize: compact ? 12.7 : 13.4,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: compact ? 13 : 14,
                          color: const Color(0xFF7A847D),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.jamInput,
                          style: TextStyle(
                            color: const Color(0xFF7A847D),
                            fontSize: compact ? 9.3 : 9.9,
                            height: 1.05,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: compact ? 29 : 31,
                color: const Color(0xFFD9E1D8),
              ),
              SizedBox(width: compact ? 8 : 9),
              Container(
                constraints: BoxConstraints(minWidth: compact ? 47 : 51),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 9 : 10,
                  vertical: compact ? 5 : 6,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F6E8),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${item.janjang}',
                  style: TextStyle(
                    color: const Color(0xFF0C7338),
                    fontSize: compact ? 13.2 : 14.0,
                    height: 1,
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
      padding: EdgeInsets.fromLTRB(
        compact ? 9 : 10,
        compact ? 7 : 8,
        compact ? 9 : 10,
        compact ? 8 : 9,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5EAE4), width: .9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .018),
            blurRadius: 9,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: compact ? 29 : 31,
                height: compact ? 29 : 31,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF6EC),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: const Color(0xFF0C7338),
                  size: compact ? 17 : 18,
                ),
              ),
              SizedBox(width: compact ? 8 : 9),
              Expanded(
                child: Text(
                  'Blok $block',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF131A14),
                    fontSize: compact ? 13.5 : 14.3,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$subtotal Janjang',
                maxLines: 1,
                style: TextStyle(
                  color: const Color(0xFF0C7338),
                  fontSize: compact ? 11.7 : 12.4,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(
                width: compact ? 29 : 31,
                height: compact ? 29 : 31,
                child: PopupMenuButton<int>(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  splashRadius: 18,
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Color(0xFF6C766F),
                  ),
                  onSelected: (index) {
                    if (index >= 0 && index < items.length) {
                      onItemMenu(items[index]);
                    }
                  },
                  itemBuilder: (_) => [
                    for (var i = 0; i < items.length; i++)
                      PopupMenuItem<int>(
                        value: i,
                        child: Text(
                          '${_pemanen(items[i])} • ${items[i].janjang} Janjang',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) SizedBox(height: compact ? 5 : 6),
          for (var i = 0; i < items.length; i++) ...[
            _itemRow(items[i]),
            if (i != items.length - 1) SizedBox(height: compact ? 5 : 6),
          ],
        ],
      ),
    );
  }
}
