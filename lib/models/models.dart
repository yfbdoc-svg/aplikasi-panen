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
  const DataHitung({
    this.id,
    required this.tanggal,
    required this.jamInput,
    required this.noPemanen,
    required this.namaPemanen,
    required this.blok,
    required this.janjang,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'tanggal': tanggal,
    'jam_input': jamInput,
    'no_pemanen': noPemanen,
    'nama_pemanen': namaPemanen,
    'blok': blok,
    'janjang': janjang,
  };

  factory DataHitung.fromMap(Map<String, Object?> m) => DataHitung(
    id: m['id'] as int?,
    tanggal: m['tanggal'] as String,
    jamInput: m['jam_input'] as String,
    noPemanen: m['no_pemanen'] as String,
    namaPemanen: m['nama_pemanen'] as String,
    blok: m['blok']?.toString() ?? '',
    janjang: m['janjang'] as int,
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
  const MasterBlok({this.id, required this.kode});

  Map<String, Object?> toMap() => {'id': id, 'kode_blok': kode};

  factory MasterBlok.fromMap(Map<String, Object?> m) => MasterBlok(
    id: m['id'] as int?,
    kode: m['kode_blok'] as String,
  );
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

  const DataTruk({
    this.id,
    required this.tanggal,
    required this.jamInput,
    required this.namaTruk,
    required this.blok,
    this.noPemanen = '',
    required this.pemanen,
    required this.janjang,
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
  };

  factory DataTruk.fromMap(Map<String, Object?> m) => DataTruk(
    id: m['id'] as int?,
    tanggal: m['tanggal'] as String,
    jamInput: m['jam_input'] as String,
    namaTruk: m['nama_truk'] as String,
    blok: m['blok'] as String,
    noPemanen: m['no_pemanen']?.toString() ?? '',
    pemanen: m['pemanen'] as String,
    janjang: m['janjang'] as int,
  );
}
