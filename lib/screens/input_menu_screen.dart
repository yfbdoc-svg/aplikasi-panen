import 'package:flutter/material.dart';

import 'data_hitung_screen.dart';
import 'data_truk_screen.dart';
import 'info_pemanen_screen.dart';
import 'operasional_harian_screen.dart';

class InputMenuScreen extends StatelessWidget {
  const InputMenuScreen({super.key});

  static const green = Color(0xFF176B2C);
  static const softGreen = Color(0xFFEAF5E7);
  static const border = Color(0xFFE5E8E3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF7),
      appBar: AppBar(
        title: const Text(
          'Operasional',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Text(
            'PEKERJAAN HARIAN',
            style: TextStyle(
              color: green,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: .2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Menu utama untuk kegiatan operasional harian di lapangan.',
            style: TextStyle(
              color: Color(0xFF6F756F),
              fontSize: 12.8,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          _inputCard(
            context,
            color: const Color(0xFFE7F5E9),
            icon: Icons.fact_check_rounded,
            title: 'Absensi Per Blok',
            subtitle: 'Tentukan blok dan pemanen yang bekerja di setiap blok.',
            page: const OperasionalHarianScreen(),
          ),
          const SizedBox(height: 12),
          _inputCard(
            context,
            color: const Color(0xFFFFF0D8),
            icon: Icons.calculate_rounded,
            title: 'Data Hitung',
            subtitle: 'Input hasil hitung janjang per blok dan pemanen.',
            page: const DataHitungScreen(),
          ),
          const SizedBox(height: 12),
          _inputCard(
            context,
            color: const Color(0xFFE9F1FF),
            icon: Icons.groups_rounded,
            title: 'Info Pemanen',
            subtitle: 'Lihat dan kelola data pemanen harian.',
            page: const InfoPemanenScreen(),
          ),
          const SizedBox(height: 12),
          _inputCard(
            context,
            color: const Color(0xFFFFECE8),
            icon: Icons.local_shipping_rounded,
            title: 'Data Truk',
            subtitle: 'Input dan kelola data angkutan TBS.',
            page: const DataTrukScreen(),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF7EC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDCE9D8)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_outlined, color: green),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Master Data, Backup, dan Pengaturan kini berada pada menu Lainnya.',
                    style: TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputCard(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: green, size: 25),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1D241E),
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF6F756F), fontSize: 12.7, height: 1.25),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF7D837D)),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
      ),
    );
  }
}
