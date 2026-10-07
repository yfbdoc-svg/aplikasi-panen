import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/date_utils.dart';
import '../database/database_helper.dart';
import '../models/info_pemanen_model.dart';
import '../models/models.dart';

class DashboardScreen extends StatefulWidget {
  final int refreshToken;

  const DashboardScreen({
    super.key,
    required this.refreshToken,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const green = Color(0xFF176B2C);
  static const darkGreen = Color(0xFF0C5E2B);
  static const ink = Color(0xFF172119);
  static const muted = Color(0xFF667166);
  static const line = Color(0xFFD9E4D8);
  static const page = Color(0xFFF5F7F2);

  Map<String, int> hitungStats = const {
    'janjang': 0,
    'pemanen': 0,
    'input': 0,
  };

  List<Pemanen> hadir = [];
  List<MasterBlok> blokPanen = [];
  List<Pemanen> masterPemanen = [];
  List<MasterBlok> masterBlok = [];
  List<InfoPemanen> infoPemanen = [];
  List<DataHitung> dataHitung = [];
  List<DataTruk> dataTruk = [];
  Map<int, Set<int>> penempatan = {};

  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);

    final today = dateKey(DateTime.now());
    try {
      final results = await Future.wait<dynamic>([
        DatabaseHelper.instance.dashboardTanggal(today),
        DatabaseHelper.instance.getPemanenHadirTanggal(today),
        DatabaseHelper.instance.getBlokPanenTanggal(today),
        DatabaseHelper.instance.getPemanen(),
        DatabaseHelper.instance.getMasterBlok(),
        DatabaseHelper.instance.getInfoPemanenTanggal(today),
        DatabaseHelper.instance.getDataHitungTanggal(today),
        DatabaseHelper.instance.getDataTrukRentang(today, today),
        DatabaseHelper.instance.getPenempatanHarianIds(today),
      ]);

      if (!mounted) return;
      setState(() {
        hitungStats = results[0] as Map<String, int>;
        hadir = results[1] as List<Pemanen>;
        blokPanen = results[2] as List<MasterBlok>;
        masterPemanen = results[3] as List<Pemanen>;
        masterBlok = results[4] as List<MasterBlok>;
        infoPemanen = results[5] as List<InfoPemanen>;
        dataHitung = results[6] as List<DataHitung>;
        dataTruk = results[7] as List<DataTruk>;
        penempatan = results[8] as Map<int, Set<int>>;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat Dashboard. Tarik layar untuk mencoba lagi.')),
      );
    }
  }

  String get latestTime {
    final times = <String>[
      ...dataHitung.map((e) => e.jamInput),
      ...infoPemanen.map((e) => e.jamInput),
      ...dataTruk.map((e) => e.jamInput),
    ]..removeWhere((e) => e.trim().isEmpty);

    if (times.isEmpty) return '--:--';
    times.sort();
    return times.last;
  }

  bool get operationalReady => hadir.isNotEmpty && blokPanen.isNotEmpty;

  String _number(int value) {
    final text = value.toString();
    final out = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final remaining = text.length - i;
      out.write(text[i]);
      if (remaining > 1 && remaining % 3 == 1) out.write('.');
    }
    return out.toString();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _DashboardMetrics.fromWidth(MediaQuery.sizeOf(context).width);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: const Color(0xFF2C8036),
        systemNavigationBarColor: const Color(0xFFF8FAF8),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: page,
        body: RefreshIndicator(
          onRefresh: _load,
          color: green,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(metrics)),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        metrics.pagePadding,
                        metrics.contentTopGap,
                        metrics.pagePadding,
                        14,
                      ),
                      child: loading
                          ? const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(
                                minHeight: 2,
                                color: green,
                                backgroundColor: Color(0xFFE2E9E1),
                              ),
                            )
                          : Column(
                              children: [
                                _operationalStatus(metrics),
                                SizedBox(height: metrics.gapOperationalToKpi),
                                _kpiGrid(metrics),
                                SizedBox(height: metrics.gapKpiToBlock),
                                _blockPanel(metrics),
                                SizedBox(height: metrics.gapBlockToActivity),
                                _activityPanel(metrics),
                                SizedBox(height: metrics.gapActivityToLast),
                                _lastActivityCard(metrics),
                              ],
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

  Widget _header(_DashboardMetrics m) {
    final width = MediaQuery.sizeOf(context).width;
    // Proporsi header mengikuti mockup: sekitar 35.5% dari lebar layar.
    // BoxFit.cover menjaga rasio gambar dan alignment kanan menjaga pohon utama.
    final headerHeight = (width * 0.355).clamp(126.0, 178.0);
    final left = width >= 600 ? 30.0 : (m.narrow ? 18.0 : 22.0);

    return SizedBox(
      height: headerHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/headers/dashboard_header_user.png',
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Colors.black.withValues(alpha: .07),
                  Colors.transparent,
                ],
                stops: const [0, .60],
              ),
            ),
          ),
          Positioned(
            left: left,
            top: headerHeight * 0.18,
            right: width * 0.40,
            child: Text(
              'KERANI SAWIT',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: m.narrow ? 24.5 : (m.compact ? 27.5 : 31),
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: -.55,
              ),
            ),
          ),
          Positioned(
            left: left,
            top: headerHeight * 0.37,
            right: width * 0.44,
            child: Text(
              'Sawit Lamandau Raya',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .97),
                fontSize: m.narrow ? 12.2 : (m.compact ? 13.2 : 14.8),
                fontWeight: FontWeight.w500,
                height: 1.05,
              ),
            ),
          ),
          Positioned(
            left: left,
            top: headerHeight * 0.56,
            right: width * 0.40,
            child: Row(
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: m.compact ? 17.5 : 19.5,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayDayDate(DateTime.now()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: m.narrow ? 10.8 : (m.compact ? 11.8 : 13),
                      fontWeight: FontWeight.w600,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: headerHeight * 0.075,
            right: width >= 600 ? 28 : (m.narrow ? 16 : 20),
            child: Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: m.compact ? 24 : 27,
            ),
          ),
        ],
      ),
    );
  }

  Widget _operationalStatus(_DashboardMetrics m) {
    final ready = operationalReady;
    final accent = ready ? const Color(0xFF5EAE5C) : const Color(0xFFD69A42);
    final soft = ready ? const Color(0xFFD9EFD0) : const Color(0xFFFFF3DF);

    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: EdgeInsets.symmetric(
        horizontal: m.compact ? 12 : 14,
        vertical: m.compact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F9F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDCE9D8)),
      ),
      child: Row(
        children: [
          Container(
            width: m.compact ? 34 : 36,
            height: m.compact ? 34 : 36,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            child: Icon(
              ready ? Icons.check_rounded : Icons.priority_high_rounded,
              color: Colors.white,
              size: m.compact ? 21 : 22,
            ),
          ),
          SizedBox(width: m.compact ? 11 : 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Operasional Hari Ini',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontSize: m.compact ? 13.5 : 14.5,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  ready
                      ? 'Seluruh sistem siap digunakan'
                      : 'Lengkapi absensi dan blok panen hari ini',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: muted,
                    fontSize: m.compact ? 9.8 : 10.5,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 58),
            padding: EdgeInsets.symmetric(
              horizontal: m.compact ? 13 : 15,
              vertical: m.compact ? 7 : 8,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              ready ? 'Siap' : 'Belum Siap',
              maxLines: 1,
              style: TextStyle(
                color: ready ? darkGreen : const Color(0xFF8A5A15),
                fontSize: m.compact ? 10.5 : 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiGrid(_DashboardMetrics m) {
    final cards = <Widget>[
      _KpiCard(
        compact: m.compact,
        icon: Icons.groups_rounded,
        iconBg: const Color(0xFFDDF1DE),
        iconColor: darkGreen,
        background: const Color(0xFFF5FBF6),
        label: 'Pemanen Hadir',
        value: '${hadir.length}',
        note: masterPemanen.isEmpty
            ? 'Master belum tersedia'
            : 'dari ${masterPemanen.length} pemanen terdaftar',
      ),
      _KpiCard(
        compact: m.compact,
        icon: Icons.map_rounded,
        iconBg: const Color(0xFFF6E5C0),
        iconColor: const Color(0xFF8E641B),
        background: const Color(0xFFFCF7EE),
        label: 'Blok Panen',
        value: '${blokPanen.length}',
        note: masterBlok.isEmpty
            ? 'Master belum tersedia'
            : 'dari ${masterBlok.length} blok terjadwal',
      ),
      _KpiCard(
        compact: m.compact,
        icon: Icons.grain_rounded,
        iconBg: const Color(0xFFF8DFD0),
        iconColor: const Color(0xFF9B3D24),
        background: const Color(0xFFFFF3EC),
        label: 'Total Janjang',
        value: _number(hitungStats['janjang'] ?? 0),
        note: 'janjang hari ini',
      ),
      _KpiCard(
        compact: m.compact,
        icon: Icons.local_shipping_rounded,
        iconBg: const Color(0xFFD8EAF8),
        iconColor: const Color(0xFF1F5E88),
        background: const Color(0xFFF0F7FE),
        label: 'Ritase',
        value: '${dataTruk.length}',
        note: dataTruk.isEmpty ? 'belum ada pengangkutan' : 'ritase keluar ke pabrik',
      ),
    ];

    if (!m.twoColumn) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            SizedBox(height: m.kpiHeight, child: cards[i]),
            if (i != cards.length - 1) SizedBox(height: m.cardGap),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - m.cardGap) / 2;
        return Wrap(
          spacing: m.cardGap,
          runSpacing: m.cardGap,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                height: m.kpiHeight,
                child: card,
              ),
          ],
        );
      },
    );
  }

  Widget _blockPanel(_DashboardMetrics m) {
    final rows = <({String kode, int count})>[];
    for (final blok in blokPanen) {
      final id = blok.id;
      rows.add((
        kode: blok.kode,
        count: id == null ? 0 : (penempatan[id]?.length ?? 0),
      ));
    }

    return _InformationPanel(
      compact: m.compact,
      background: const Color(0xFFF1F8EE),
      icon: Icons.map_rounded,
      title: 'Blok Panen Hari Ini',
      trailing: '${blokPanen.length} blok',
      innerBackground: Colors.white,
      child: rows.isEmpty
          ? const _EmptyState(
              icon: Icons.map_outlined,
              text: 'Blok panen hari ini belum ditetapkan.',
            )
          : Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  _BlockRow(
                    compact: m.compact,
                    code: rows[i].kode,
                    workerCount: rows[i].count,
                  ),
                  if (i != rows.length - 1)
                    const Divider(height: 1, color: line),
                ],
              ],
            ),
    );
  }

  Widget _activityPanel(_DashboardMetrics m) {
    return _InformationPanel(
      compact: m.compact,
      background: const Color(0xFFF1F8EE),
      icon: Icons.assignment_rounded,
      title: 'Aktivitas Hari Ini',
      innerBackground: Colors.white,
      child: Column(
        children: [
          _ActivityInfoRow(
            compact: m.compact,
            icon: Icons.description_rounded,
            iconBackground: const Color(0xFFDDEFE2),
            iconColor: darkGreen,
            title: 'Data Hitung',
            subtitle: 'Rekap janjang dari blok panen',
            value: _number(hitungStats['janjang'] ?? 0),
          ),
          const Divider(height: 1, color: line),
          _ActivityInfoRow(
            compact: m.compact,
            icon: Icons.groups_rounded,
            iconBackground: const Color(0xFFF3E7C9),
            iconColor: const Color(0xFF8E641B),
            title: 'Info Pemanen',
            subtitle: 'Data kehadiran dan pembagian blok',
            value: '${infoPemanen.length}',
          ),
          const Divider(height: 1, color: line),
          _ActivityInfoRow(
            compact: m.compact,
            icon: Icons.local_shipping_rounded,
            iconBackground: const Color(0xFFD8EAF8),
            iconColor: const Color(0xFF1F5E88),
            title: 'Data Truk',
            subtitle: 'Ritase dan pengiriman ke pabrik',
            value: '${dataTruk.length}',
          ),
        ],
      ),
    );
  }

  Widget _lastActivityCard(_DashboardMetrics m) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: m.compact ? 12 : 14,
        vertical: m.compact ? 7 : 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8E6D4)),
      ),
      child: Row(
        children: [
          Container(
            width: m.compact ? 34 : 36,
            height: m.compact ? 34 : 36,
            decoration: const BoxDecoration(
              color: Color(0xFF62A85D),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.schedule_rounded,
              color: Colors.white,
              size: m.compact ? 20 : 21,
            ),
          ),
          SizedBox(width: m.compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aktivitas Terakhir',
                  style: TextStyle(
                    color: darkGreen,
                    fontSize: m.compact ? 13.5 : 14.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Terakhir diperbarui pada',
                  style: TextStyle(
                    color: muted,
                    fontSize: m.compact ? 9.7 : 10.5,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                shortDateDisplay(DateTime.now()),
                style: TextStyle(
                  color: muted,
                  fontSize: m.compact ? 9.7 : 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                latestTime,
                style: TextStyle(
                  color: darkGreen,
                  fontSize: m.compact ? 14.5 : 15.5,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardMetrics {
  final bool narrow;
  final bool compact;
  final bool twoColumn;
  final double pagePadding;
  final double headerHorizontal;
  final double contentTopGap;
  final double gapOperationalToKpi;
  final double gapKpiToBlock;
  final double gapBlockToActivity;
  final double gapActivityToLast;
  final double cardGap;
  final double kpiHeight;

  const _DashboardMetrics({
    required this.narrow,
    required this.compact,
    required this.twoColumn,
    required this.pagePadding,
    required this.headerHorizontal,
    required this.contentTopGap,
    required this.gapOperationalToKpi,
    required this.gapKpiToBlock,
    required this.gapBlockToActivity,
    required this.gapActivityToLast,
    required this.cardGap,
    required this.kpiHeight,
  });

  factory _DashboardMetrics.fromWidth(double width) {
    final narrow = width < 360;
    final compact = width < 420;
    return _DashboardMetrics(
      narrow: narrow,
      compact: compact,
      twoColumn: width >= 360,
      pagePadding: width >= 600 ? 18 : (narrow ? 12 : 14),
      headerHorizontal: width >= 600 ? 26 : (narrow ? 18 : 22),
      // Ritme vertikal mengikuti mockup, bukan satu gap seragam.
      contentTopGap: narrow ? 4 : 5,
      gapOperationalToKpi: narrow ? 7 : 8,
      gapKpiToBlock: narrow ? 8 : 10,
      gapBlockToActivity: narrow ? 7 : 8,
      gapActivityToLast: narrow ? 6 : 7,
      cardGap: narrow ? 7 : 8,
      kpiHeight: narrow ? 68 : 70,
    );
  }
}

class _KpiCard extends StatelessWidget {
  final bool compact;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color background;
  final String label;
  final String value;
  final String note;

  const _KpiCard({
    required this.compact,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.background,
    required this.label,
    required this.value,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 10,
        vertical: compact ? 8 : 9,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 40 : 42,
            height: compact ? 40 : 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: compact ? 22 : 24),
          ),
          SizedBox(width: compact ? 9 : 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _DashboardScreenState.ink,
                    fontSize: compact ? 11.6 : 12.4,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: compact ? 20 : 22,
                      height: .95,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _DashboardScreenState.muted,
                    fontSize: compact ? 8.7 : 9.4,
                    height: 1.08,
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

class _InformationPanel extends StatelessWidget {
  final bool compact;
  final Color background;
  final Color innerBackground;
  final IconData icon;
  final String title;
  final String? trailing;
  final Widget child;

  const _InformationPanel({
    required this.compact,
    required this.background,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.innerBackground = const Color(0xFFF8FAF6),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _DashboardScreenState.line),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 11 : 12, compact ? 9 : 10, compact ? 11 : 12, compact ? 7 : 8),
            child: Row(
              children: [
                Icon(icon, color: _DashboardScreenState.darkGreen, size: compact ? 18 : 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _DashboardScreenState.darkGreen,
                      fontSize: compact ? 14.5 : 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (trailing != null)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 11, vertical: compact ? 5 : 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDEFD9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      trailing!,
                      maxLines: 1,
                      style: TextStyle(
                        color: _DashboardScreenState.darkGreen,
                        fontSize: compact ? 10.2 : 10.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            margin: EdgeInsets.fromLTRB(compact ? 7 : 8, 0, compact ? 7 : 8, compact ? 7 : 8),
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 11, vertical: 0),
            decoration: BoxDecoration(
              color: innerBackground,
              borderRadius: BorderRadius.circular(11),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _BlockRow extends StatelessWidget {
  final bool compact;
  final String code;
  final int workerCount;

  const _BlockRow({
    required this.compact,
    required this.code,
    required this.workerCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              code,
              style: TextStyle(
                color: _DashboardScreenState.ink,
                fontSize: compact ? 12.7 : 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '$workerCount pemanen',
            style: TextStyle(
              color: _DashboardScreenState.muted,
              fontSize: compact ? 11.3 : 12.0,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.chevron_right_rounded,
            size: compact ? 18 : 19,
            color: const Color(0xFF707B70),
          ),
        ],
      ),
    );
  }
}

class _ActivityInfoRow extends StatelessWidget {
  final bool compact;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String value;

  const _ActivityInfoRow({
    required this.compact,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 4 : 5),
      child: Row(
        children: [
          Container(
            width: compact ? 31 : 33,
            height: compact ? 31 : 33,
            decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: compact ? 18 : 19),
          ),
          SizedBox(width: compact ? 9 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _DashboardScreenState.ink,
                    fontSize: compact ? 12.5 : 13.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _DashboardScreenState.muted,
                    fontSize: compact ? 9.4 : 10.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 90 : 120),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: _DashboardScreenState.ink,
                  fontSize: compact ? 14.5 : 15.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            size: compact ? 19 : 20,
            color: const Color(0xFF707B70),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF96A296), size: 28),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _DashboardScreenState.muted,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
