import 'package:flutter/material.dart';

import 'master_blok_screen.dart';
import 'master_pemanen_screen.dart';
import 'master_truk_screen.dart';

class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  static const green = Color(0xFF176B2C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F6),
      appBar: AppBar(
        title: const Text(
          'Lainnya',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          _sectionTitle('Master Data', 'Kelola data utama yang digunakan pada operasional.'),
          const SizedBox(height: 12),
          _menuCard(
            context,
            icon: Icons.manage_accounts_rounded,
            title: 'Master Pemanen',
            subtitle: 'Kelola nomor dan nama pemanen.',
            color: const Color(0xFFE8F4E9),
            page: const MasterPemanenScreen(),
          ),
          const SizedBox(height: 10),
          _menuCard(
            context,
            icon: Icons.map_rounded,
            title: 'Master Blok',
            subtitle: 'Kelola kode blok kebun.',
            color: const Color(0xFFFFF1D8),
            page: const MasterBlokScreen(),
          ),
          const SizedBox(height: 10),
          _menuCard(
            context,
            icon: Icons.local_shipping_rounded,
            title: 'Master Angkutan',
            subtitle: 'Kelola TRUK dan LD/Jonder operasional.',
            color: const Color(0xFFE8F0FF),
            page: const MasterTrukScreen(),
          ),
          const SizedBox(height: 22),
          _sectionTitle('Utilitas', 'Menu tambahan untuk pengelolaan aplikasi.'),
          const SizedBox(height: 12),
          _actionCard(
            context,
            icon: Icons.cloud_upload_rounded,
            title: 'Backup & Restore',
            subtitle: 'Cadangkan dan pulihkan data aplikasi.',
            color: const Color(0xFFE8F5FF),
          ),
          const SizedBox(height: 10),
          _actionCard(
            context,
            icon: Icons.settings_rounded,
            title: 'Pengaturan',
            subtitle: 'Pengaturan umum aplikasi.',
            color: const Color(0xFFEEF0F3),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: Color(0xFF182118),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12.8,
            color: Color(0xFF667066),
          ),
        ),
      ],
    );
  }

  Widget _menuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Widget page,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8E1)),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: green, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF667066), fontSize: 12.7, height: 1.25),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF7D857D)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title belum diaktifkan.')),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8E1)),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: green, size: 27),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF667066), fontSize: 12.7, height: 1.25),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF7D857D)),
            ],
          ),
        ),
      ),
    );
  }
}
