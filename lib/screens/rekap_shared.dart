import 'package:flutter/material.dart';

import '../app/date_utils.dart';

const rekapGreen = Color(0xFF176B2C);

String formatRekapNumber(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < raw.length; i++) {
    final remaining = raw.length - i;
    buffer.write(raw[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write('.');
    }
  }
  return buffer.toString();
}

String rekapRangeLabel(DateTime start, DateTime end) {
  final same = start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  if (same) return displayDate(start);
  return '${displayDate(start)} – ${displayDate(end)}';
}

class RekapRangeCard extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onChooseRange;
  final VoidCallback onToday;

  const RekapRangeCard({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.onChooseRange,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E8E2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF5E7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.date_range_rounded, color: rekapGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Periode Rekap',
                  style: TextStyle(
                    color: Color(0xFF6B746B),
                    fontSize: 11.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  rekapRangeLabel(startDate, endDate),
                  style: const TextStyle(
                    color: Color(0xFF1E281F),
                    fontSize: 14.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hari ini',
            onPressed: onToday,
            icon: const Icon(Icons.today_rounded, color: rekapGreen),
          ),
          IconButton(
            tooltip: 'Pilih periode',
            onPressed: onChooseRange,
            icon: const Icon(Icons.tune_rounded, color: rekapGreen),
          ),
        ],
      ),
    );
  }
}

class RekapMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  const RekapMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E8E2)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: rekapGreen, size: 23),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF697269),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF123E20),
                    fontSize: 19,
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

class RekapEmptyState extends StatelessWidget {
  final String message;

  const RekapEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E8E2)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 42,
            color: Color(0xFF96A096),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF687168),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
