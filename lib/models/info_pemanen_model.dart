class InfoPemanen {
  final int? id;
  final String tanggal;
  final String jamInput;
  final String noPemanen;
  final String namaPemanen;
  final String blok;
  final int janjang;

  const InfoPemanen({
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

  factory InfoPemanen.fromMap(Map<String, Object?> map) {
    return InfoPemanen(
      id: map['id'] as int?,
      tanggal: map['tanggal'] as String,
      jamInput: map['jam_input'] as String,
      noPemanen: map['no_pemanen'] as String,
      namaPemanen: map['nama_pemanen'] as String,
      blok: map['blok']?.toString() ?? '',
      janjang: map['janjang'] as int,
    );
  }
}
