class Pemanen {
  final int? id;
  final String no;
  final String nama;
  const Pemanen({this.id, required this.no, required this.nama});

  Map<String, Object?> toMap() => {
    'id': id,
    'no_pemanen': no,
    'nama_pemanen': nama,
  };

  factory Pemanen.fromMap(Map<String, Object?> m) => Pemanen(
    id: m['id'] as int?,
    no: m['no_pemanen'] as String,
    nama: m['nama_pemanen'] as String,
  );
}

class DataHitung {
  final int? id;
  final String tanggal;
  final String jamInput;
  final String noPemanen;
  final String namaPemanen;
  final String blok;
  final int janjang;
  final double bjrSnapshot;
  const DataHitung({
    this.id,
    required this.tanggal,
    required this.jamInput,
    required this.noPemanen,
    required this.namaPemanen,
    required this.blok,
    required this.janjang,
    this.bjrSnapshot = 0,
  });

  double get estimasiKg => janjang * bjrSnapshot;

  Map<String, Object?> toMap() => {
    'id': id,
    'tanggal': tanggal,
    'jam_input': jamInput,
    'no_pemanen': noPemanen,
    'nama_pemanen': namaPemanen,
    'blok': blok,
    'janjang': janjang,
    'bjr_snapshot': bjrSnapshot,
  };

  factory DataHitung.fromMap(Map<String, Object?> m) => DataHitung(
    id: m['id'] as int?,
    tanggal: m['tanggal'] as String,
    jamInput: m['jam_input'] as String,
    noPemanen: m['no_pemanen'] as String,
    namaPemanen: m['nama_pemanen'] as String,
    blok: m['blok']?.toString() ?? '',
    janjang: m['janjang'] as int,
    bjrSnapshot: (m['bjr_snapshot'] as num?)?.toDouble() ?? 0,
  );
}

class MasterTruk {
  final int? id;
  final String nama;
  const MasterTruk({this.id, required this.nama});

  Map<String, Object?> toMap() => {'id': id, 'nama_truk': nama};

  factory MasterTruk.fromMap(Map<String, Object?> m) => MasterTruk(
    id: m['id'] as int?,
    nama: m['nama_truk'] as String,
  );
}

class MasterBlok {
  final int? id;
  final String kode;
  final double bjr;
  final int? tahunTanam;
  final double? luasHa;

  const MasterBlok({
    this.id,
    required this.kode,
    this.bjr = 0,
    this.tahunTanam,
    this.luasHa,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'kode_blok': kode,
    'bjr': bjr,
    'tahun_tanam': tahunTanam,
    'luas_ha': luasHa,
  };

  factory MasterBlok.fromMap(Map<String, Object?> m) => MasterBlok(
    id: m['id'] as int?,
    kode: m['kode_blok'] as String,
    bjr: (m['bjr'] as num?)?.toDouble() ?? 0,
    tahunTanam: (m['tahun_tanam'] as num?)?.toInt(),
    luasHa: (m['luas_ha'] as num?)?.toDouble(),
  );

  String get detailSingkat {
    final parts = <String>[];
    parts.add(bjr > 0 ? 'BJR ${bjr.toStringAsFixed(2).replaceAll('.', ',')}' : 'BJR -');
    parts.add(tahunTanam == null ? 'TT -' : 'TT $tahunTanam');
    if (luasHa != null && luasHa! > 0) {
      parts.add('${luasHa!.toStringAsFixed(2).replaceAll('.', ',')} Ha');
    }
    return parts.join('  |  ');
  }
}

class DataTruk {
  final int? id;
  final String tanggal;
  final String jamInput;
  final String namaTruk;
  final String blok;

  // Nomor pemanen disimpan bersama nama agar riwayat Data Truk tetap utuh
  // walaupun master pemanen kemudian diedit.
  final String noPemanen;
  final String pemanen;

  final int janjang;
  final double bjrSnapshot;

  const DataTruk({
    this.id,
    required this.tanggal,
    required this.jamInput,
    required this.namaTruk,
    required this.blok,
    this.noPemanen = '',
    required this.pemanen,
    required this.janjang,
    this.bjrSnapshot = 0,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'tanggal': tanggal,
    'jam_input': jamInput,
    'nama_truk': namaTruk,
    'blok': blok,
    'no_pemanen': noPemanen,
    'pemanen': pemanen,
    'janjang': janjang,
    'bjr_snapshot': bjrSnapshot,
  };

  double get estimasiKg => janjang * bjrSnapshot;

  factory DataTruk.fromMap(Map<String, Object?> m) => DataTruk(
    id: m['id'] as int?,
    tanggal: m['tanggal'] as String,
    jamInput: m['jam_input'] as String,
    namaTruk: m['nama_truk'] as String,
    blok: m['blok'] as String,
    noPemanen: m['no_pemanen']?.toString() ?? '',
    pemanen: m['pemanen'] as String,
    janjang: m['janjang'] as int,
    bjrSnapshot: (m['bjr_snapshot'] as num?)?.toDouble() ?? 0,
  );
}
