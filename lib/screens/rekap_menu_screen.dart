import 'package:flutter/material.dart';

import 'rekap_blok_screen.dart';
import 'rekap_hitung_screen.dart';
import 'rekap_info_pemanen_screen.dart';
import 'rekap_pemanen_screen.dart';
import 'rekap_truk_screen.dart';

class RekapMenuScreen extends StatelessWidget {
  final int refreshToken;

  const RekapMenuScreen({super.key, this.refreshToken = 0});

  static const green = Color(0xFF176B2C);


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F6),
      appBar: AppBar(
        title: const Text(
          'Rekap',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          const Text(
            'Laporan & Ringkasan',
            style: TextStyle(
              color: Color(0xFF1D241D),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pilih jenis rekap yang ingin ditampilkan.',
            style: TextStyle(color: Color(0xFF657065), fontSize: 12.8),
          ),
          const SizedBox(height: 14),
          _RekapChoiceCard(
            icon: Icons.description_rounded,
            title: 'Rekap Data Hitung',
            subtitle: 'Rekap hasil hitung janjang per pemanen dan total harian.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RekapHitungScreen(refreshToken: refreshToken),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _RekapChoiceCard(
            icon: Icons.groups_rounded,
            title: 'Rekap Info Pemanen',
            subtitle: 'Ringkasan kehadiran dan hasil kerja pemanen.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RekapInfoPemanenScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _RekapChoiceCard(
            icon: Icons.local_shipping_rounded,
            title: 'Rekap Data Truk',
            subtitle: 'Rekap pengangkutan berdasarkan tanggal, truk, blok, dan pemanen.',
            emphasized: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RekapTrukScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _RekapChoiceCard(
            icon: Icons.map_rounded,
            title: 'Rekap per Blok',
            subtitle: 'Ringkasan hasil panen berdasarkan blok.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RekapBlokScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _RekapChoiceCard(
            icon: Icons.person_rounded,
            title: 'Rekap per Pemanen',
            subtitle: 'Ringkasan hasil panen berdasarkan pemanen.',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RekapPemanenScreen()),
              );
            },
          ),
          const SizedBox(height: 18),
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
                    'Gunakan filter tanggal untuk melihat rekap pada periode tertentu.',
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
}

class _RekapChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasized;

  const _RekapChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF176B2C);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: emphasized ? green : const Color(0xFFE3E7E1),
              width: emphasized ? 1.2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF5E7),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: green, size: 29),
              ),
              const SizedBox(width: 14),
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
                      style: const TextStyle(
                        color: Color(0xFF626862),
                        fontSize: 12.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF626862)),
            ],
          ),
        ),
      ),
    );
  }
}
