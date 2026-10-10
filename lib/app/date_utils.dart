String dateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime parseDateKey(String value) {
  final p = value.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String displayDate(DateTime date) {
  const months = [
    'Januari','Februari','Maret','April','Mei','Juni',
    'Juli','Agustus','September','Oktober','November','Desember'
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String displayDayDate(DateTime date) {
  const days = [
    'Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu'
  ];
  return '${days[date.weekday - 1]}, ${displayDate(date)}';
}

String timeText(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String shortDateDisplay(DateTime date) {
  const months = [
    'Jan','Feb','Mar','Apr','Mei','Jun',
    'Jul','Agu','Sep','Okt','Nov','Des'
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
