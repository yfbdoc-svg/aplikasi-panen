import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';
import '../models/info_pemanen_model.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final base = await getDatabasesPath();
    final path = p.join(base, 'KeraniSawit.db');

    return openDatabase(
      path,
      version: 12,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Database masih tahap pengembangan. Database sebelum v8 dibangun
        // ulang agar tidak membawa struktur legacy.
        if (oldVersion < 8) {
          await _dropLegacySchema(db);
          await _createSchema(db);
          return;
        }

        // v9 menambahkan kolom blok pada Info Pemanen.
        if (oldVersion < 9) {
          await db.execute(
            "ALTER TABLE info_pemanen ADD COLUMN blok TEXT NOT NULL DEFAULT ''",
          );
        }

        // v10: operasional harian disederhanakan menjadi penempatan pemanen
        // per blok. Setup harian v9 direset karena belum menyimpan relasi blok.
        if (oldVersion < 10) {
          await db.execute('DROP TABLE IF EXISTS absensi_pemanen');
          await db.execute('DROP TABLE IF EXISTS blok_panen_harian');
          await _createDailyAssignmentSchema(db);
        }


        // v11: Master Blok menyimpan BJR dan Tahun Tanam. Kolom baru
        // ditambahkan tanpa menghapus data blok maupun transaksi lama.
        if (oldVersion < 11) {
          await db.execute(
            'ALTER TABLE master_blok ADD COLUMN bjr REAL NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE master_blok ADD COLUMN tahun_tanam INTEGER',
          );
        }


        // v12: Master Blok menambahkan luas Ha opsional. Data Hitung dan
        // Data Truk menyimpan snapshot BJR agar histori tidak berubah saat
        // BJR pada Master Blok diperbarui di kemudian hari.
        if (oldVersion < 12) {
          await db.execute(
            'ALTER TABLE master_blok ADD COLUMN luas_ha REAL',
          );
          await db.execute(
            'ALTER TABLE data_hitung ADD COLUMN bjr_snapshot REAL NOT NULL DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE data_truk ADD COLUMN bjr_snapshot REAL NOT NULL DEFAULT 0',
          );
        }
      },
    );
  }

  Future<void> _dropLegacySchema(Database db) async {
    await db.execute('DROP TABLE IF EXISTS target_produksi');
    await db.execute('DROP TABLE IF EXISTS produksi_harian');
    await db.execute('DROP TABLE IF EXISTS hasil_sementara');
    await db.execute('DROP TABLE IF EXISTS penempatan_pemanen_harian');
    await db.execute('DROP TABLE IF EXISTS absensi_pemanen');
    await db.execute('DROP TABLE IF EXISTS blok_panen_harian');
    await db.execute('DROP TABLE IF EXISTS info_pemanen');
    await db.execute('DROP TABLE IF EXISTS data_truk');
    await db.execute('DROP TABLE IF EXISTS data_hitung');
    await db.execute('DROP TABLE IF EXISTS master_truk');
    await db.execute('DROP TABLE IF EXISTS master_blok');
    await db.execute('DROP TABLE IF EXISTS master_pemanen');
    await db.execute('DROP TABLE IF EXISTS app_setting');
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE master_pemanen(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        no_pemanen TEXT NOT NULL UNIQUE CHECK(TRIM(no_pemanen) <> ''),
        nama_pemanen TEXT NOT NULL CHECK(TRIM(nama_pemanen) <> '')
      )
    ''');

    await db.execute('''
      CREATE TABLE master_blok(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kode_blok TEXT NOT NULL UNIQUE CHECK(TRIM(kode_blok) <> ''),
        bjr REAL NOT NULL DEFAULT 0 CHECK(bjr >= 0),
        tahun_tanam INTEGER,
        luas_ha REAL CHECK(luas_ha IS NULL OR luas_ha > 0)
      )
    ''');

    await db.execute('''
      CREATE TABLE master_truk(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama_truk TEXT NOT NULL UNIQUE CHECK(TRIM(nama_truk) <> '')
      )
    ''');

    await db.execute('''
      CREATE TABLE data_hitung(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tanggal TEXT NOT NULL,
        jam_input TEXT NOT NULL,
        no_pemanen TEXT NOT NULL,
        nama_pemanen TEXT NOT NULL,
        blok TEXT NOT NULL,
        janjang INTEGER NOT NULL CHECK(janjang > 0),
        bjr_snapshot REAL NOT NULL DEFAULT 0 CHECK(bjr_snapshot >= 0)
      )
    ''');

    await db.execute('''
      CREATE TABLE data_truk(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tanggal TEXT NOT NULL,
        jam_input TEXT NOT NULL,
        nama_truk TEXT NOT NULL,
        blok TEXT NOT NULL,
        no_pemanen TEXT NOT NULL,
        pemanen TEXT NOT NULL,
        janjang INTEGER NOT NULL CHECK(janjang > 0),
        bjr_snapshot REAL NOT NULL DEFAULT 0 CHECK(bjr_snapshot >= 0)
      )
    ''');

    await db.execute('''
      CREATE TABLE info_pemanen(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tanggal TEXT NOT NULL,
        jam_input TEXT NOT NULL,
        no_pemanen TEXT NOT NULL,
        nama_pemanen TEXT NOT NULL,
        blok TEXT NOT NULL,
        janjang INTEGER NOT NULL CHECK(janjang > 0)
      )
    ''');

    await _createDailyAssignmentSchema(db);

    await db.execute('''
      CREATE TABLE app_setting(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_data_hitung_tanggal ON data_hitung(tanggal)',
    );
    await db.execute(
      'CREATE INDEX idx_data_hitung_tanggal_pemanen '
      'ON data_hitung(tanggal, no_pemanen)',
    );
    await db.execute(
      'CREATE INDEX idx_data_truk_tanggal_truk '
      'ON data_truk(tanggal, nama_truk)',
    );
    await db.execute(
      'CREATE INDEX idx_data_truk_tanggal_pemanen '
      'ON data_truk(tanggal, no_pemanen)',
    );
    await db.execute(
      'CREATE INDEX idx_info_pemanen_tanggal ON info_pemanen(tanggal)',
    );
  }

  Future<void> _createDailyAssignmentSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS penempatan_pemanen_harian(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tanggal TEXT NOT NULL,
        blok_id INTEGER NOT NULL,
        pemanen_id INTEGER NOT NULL,
        UNIQUE(tanggal, blok_id, pemanen_id),
        FOREIGN KEY(blok_id) REFERENCES master_blok(id)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY(pemanen_id) REFERENCES master_pemanen(id)
          ON UPDATE CASCADE ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_penempatan_tanggal '
      'ON penempatan_pemanen_harian(tanggal)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_penempatan_tanggal_blok '
      'ON penempatan_pemanen_harian(tanggal, blok_id)',
    );
  }

  // ---------- SETTINGS ----------
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_setting',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_setting',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  // ---------- MASTER PEMANEN ----------
  Future<List<Pemanen>> getPemanen() async {
    final db = await database;
    final rows = await db.query(
      'master_pemanen',
      orderBy: 'CAST(no_pemanen AS INTEGER), no_pemanen',
    );
    return rows.map(Pemanen.fromMap).toList();
  }

  Future<int> addPemanen(Pemanen item) async {
    final db = await database;
    return db.insert('master_pemanen', item.toMap());
  }

  Future<int> updatePemanen(Pemanen item) async {
    final db = await database;
    return db.update(
      'master_pemanen',
      {
        'no_pemanen': item.no,
        'nama_pemanen': item.nama,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deletePemanen(int id) async {
    final db = await database;
    return db.delete(
      'master_pemanen',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- OPERASIONAL HARIAN / ABSENSI PER BLOK ----------
  Future<Map<int, Set<int>>> getPenempatanHarianIds(String tanggal) async {
    final db = await database;
    final rows = await db.query(
      'penempatan_pemanen_harian',
      columns: ['blok_id', 'pemanen_id'],
      where: 'tanggal = ?',
      whereArgs: [tanggal],
      orderBy: 'blok_id, pemanen_id',
    );

    final result = <int, Set<int>>{};
    for (final row in rows) {
      final blokId = (row['blok_id'] as num).toInt();
      final pemanenId = (row['pemanen_id'] as num).toInt();
      result.putIfAbsent(blokId, () => <int>{}).add(pemanenId);
    }
    return result;
  }

  Future<List<Pemanen>> getPemanenHadirTanggal(String tanggal) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT p.id, p.no_pemanen, p.nama_pemanen
      FROM master_pemanen p
      INNER JOIN penempatan_pemanen_harian h ON h.pemanen_id = p.id
      WHERE h.tanggal = ?
      ORDER BY CAST(p.no_pemanen AS INTEGER), p.no_pemanen
    ''', [tanggal]);
    return rows.map(Pemanen.fromMap).toList();
  }

  Future<List<MasterBlok>> getBlokPanenTanggal(String tanggal) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT b.id, b.kode_blok, b.bjr, b.tahun_tanam
      FROM master_blok b
      INNER JOIN penempatan_pemanen_harian h ON h.blok_id = b.id
      WHERE h.tanggal = ?
      ORDER BY b.kode_blok
    ''', [tanggal]);
    return rows.map(MasterBlok.fromMap).toList();
  }

  Future<List<Pemanen>> getPemanenBlokTanggal(
    String tanggal,
    String kodeBlok,
  ) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT p.id, p.no_pemanen, p.nama_pemanen
      FROM master_pemanen p
      INNER JOIN penempatan_pemanen_harian h ON h.pemanen_id = p.id
      INNER JOIN master_blok b ON b.id = h.blok_id
      WHERE h.tanggal = ? AND b.kode_blok = ?
      ORDER BY CAST(p.no_pemanen AS INTEGER), p.no_pemanen
    ''', [tanggal, kodeBlok]);
    return rows.map(Pemanen.fromMap).toList();
  }

  Future<bool> isPemanenAktifDiBlok({
    required String tanggal,
    required String kodeBlok,
    required String noPemanen,
  }) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT 1
      FROM penempatan_pemanen_harian h
      INNER JOIN master_blok b ON b.id = h.blok_id
      INNER JOIN master_pemanen p ON p.id = h.pemanen_id
      WHERE h.tanggal = ?
        AND b.kode_blok = ?
        AND p.no_pemanen = ?
      LIMIT 1
    ''', [tanggal, kodeBlok, noPemanen]);
    return rows.isNotEmpty;
  }

  Future<void> savePenempatanHarian({
    required String tanggal,
    required Map<int, Set<int>> penempatan,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'penempatan_pemanen_harian',
        where: 'tanggal = ?',
        whereArgs: [tanggal],
      );

      for (final entry in penempatan.entries) {
        for (final pemanenId in entry.value) {
          await txn.insert('penempatan_pemanen_harian', {
            'tanggal': tanggal,
            'blok_id': entry.key,
            'pemanen_id': pemanenId,
          });
        }
      }
    });
  }

  // ---------- DATA HITUNG ----------
  Future<int> addDataHitung(DataHitung item) async {
    final db = await database;
    return db.insert('data_hitung', item.toMap());
  }

  Future<List<DataHitung>> getDataHitungTanggal(String tanggal) async {
    final db = await database;
    final rows = await db.query(
      'data_hitung',
      where: 'tanggal = ?',
      whereArgs: [tanggal],
      orderBy: 'id DESC',
    );
    return rows.map(DataHitung.fromMap).toList();
  }


  Future<List<DataHitung>> getDataHitungRentang(
    String tanggalAwal,
    String tanggalAkhir,
  ) async {
    final db = await database;
    final rows = await db.query(
      'data_hitung',
      where: 'tanggal >= ? AND tanggal <= ?',
      whereArgs: [tanggalAwal, tanggalAkhir],
      orderBy:
          'tanggal ASC, CAST(no_pemanen AS INTEGER) ASC, no_pemanen ASC, id ASC',
    );
    return rows.map(DataHitung.fromMap).toList();
  }


  Future<int> deleteDataHitung(int id) async {
    final db = await database;
    return db.delete(
      'data_hitung',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateDataHitung(DataHitung item) async {
    final db = await database;
    return db.update(
      'data_hitung',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<Map<String, int>> dashboardTanggal(String tanggal) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(janjang), 0) AS total_janjang,
        COUNT(*) AS total_input,
        COUNT(DISTINCT no_pemanen) AS total_pemanen
      FROM data_hitung
      WHERE tanggal = ?
    ''', [tanggal]);

    final row = rows.first;
    return {
      'janjang': (row['total_janjang'] as num?)?.toInt() ?? 0,
      'input': (row['total_input'] as num?)?.toInt() ?? 0,
      'pemanen': (row['total_pemanen'] as num?)?.toInt() ?? 0,
    };
  }

  // ---------- MASTER TRUK ----------
  Future<List<MasterTruk>> getMasterTruk() async {
    final db = await database;
    final rows = await db.query(
      'master_truk',
      orderBy: 'nama_truk',
    );
    return rows.map(MasterTruk.fromMap).toList();
  }

  Future<int> addMasterTruk(MasterTruk item) async {
    final db = await database;
    return db.insert('master_truk', item.toMap());
  }

  Future<int> updateMasterTruk(MasterTruk item) async {
    final db = await database;
    return db.update(
      'master_truk',
      {'nama_truk': item.nama},
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteMasterTruk(int id) async {
    final db = await database;
    return db.delete(
      'master_truk',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- MASTER BLOK ----------
  Future<List<MasterBlok>> getMasterBlok() async {
    final db = await database;
    final rows = await db.query(
      'master_blok',
      orderBy: 'kode_blok',
    );
    return rows.map(MasterBlok.fromMap).toList();
  }

  Future<int> addMasterBlok(MasterBlok item) async {
    final db = await database;
    return db.insert('master_blok', item.toMap());
  }

  Future<int> updateMasterBlok(MasterBlok item) async {
    final db = await database;
    return db.update(
      'master_blok',
      {
        'kode_blok': item.kode,
        'bjr': item.bjr,
        'tahun_tanam': item.tahunTanam,
        'luas_ha': item.luasHa,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteMasterBlok(int id) async {
    final db = await database;
    return db.delete(
      'master_blok',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ---------- DATA TRUK ----------
  Future<int> addDataTruk(DataTruk item) async {
    final db = await database;
    return db.insert('data_truk', item.toMap());
  }

  Future<List<DataTruk>> getDataTrukByTanggalTruk(
    String tanggal,
    String namaTruk,
  ) async {
    final db = await database;
    final rows = await db.query(
      'data_truk',
      where: 'tanggal = ? AND nama_truk = ?',
      whereArgs: [tanggal, namaTruk],
      orderBy: 'blok, id',
    );
    return rows.map(DataTruk.fromMap).toList();
  }


  Future<List<DataTruk>> getDataTrukRentang(
    String tanggalAwal,
    String tanggalAkhir,
  ) async {
    final db = await database;
    final rows = await db.query(
      'data_truk',
      where: 'tanggal >= ? AND tanggal <= ?',
      whereArgs: [tanggalAwal, tanggalAkhir],
      orderBy:
          'tanggal ASC, nama_truk ASC, blok ASC, '
          'CAST(no_pemanen AS INTEGER) ASC, no_pemanen ASC, id ASC',
    );
    return rows.map(DataTruk.fromMap).toList();
  }



  Future<int> updateDataTruk(DataTruk item) async {
    final db = await database;
    // Saat edit muatan, ubah hanya jumlah janjang.
    // Data tanggal, jam, truk, blok, dan pemanen tetap memakai record lama.
    return db.update(
      'data_truk',
      {'janjang': item.janjang},
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteDataTruk(int id) async {
    final db = await database;
    return db.delete(
      'data_truk',
      where: 'id = ?',
      whereArgs: [id],
    );
  }



  Future<int> jumlahTphTrukTanggal(String tanggal) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS c
      FROM data_truk
      WHERE tanggal = ?
    ''', [tanggal]);

    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<int> totalJanjangTrukTanggal(String tanggal) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT SUM(janjang) AS c
      FROM data_truk
      WHERE tanggal = ?
    ''', [tanggal]);

    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<int> jumlahTrukTanggal(String tanggal) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT COUNT(DISTINCT nama_truk) AS c
      FROM data_truk
      WHERE tanggal = ?
    ''', [tanggal]);

    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  // ---------- INFO PEMANEN ----------
  


  Future<List<InfoPemanen>> getInfoPemanenTanggal(
    String tanggal,
  ) async {
    final db = await database;
    final rows = await db.query(
      'info_pemanen',
      where: 'tanggal = ?',
      whereArgs: [tanggal],
      orderBy: 'id DESC',
    );
    return rows.map(InfoPemanen.fromMap).toList();
  }

  Future<List<InfoPemanen>> getInfoPemanenRentang(
    String tanggalAwal,
    String tanggalAkhir,
  ) async {
    final db = await database;
    final rows = await db.query(
      'info_pemanen',
      where: 'tanggal >= ? AND tanggal <= ?',
      whereArgs: [tanggalAwal, tanggalAkhir],
      orderBy:
          'tanggal ASC, CAST(no_pemanen AS INTEGER) ASC, no_pemanen ASC, id ASC',
    );
    return rows.map(InfoPemanen.fromMap).toList();
  }


  Future<int> addInfoPemanen(
    InfoPemanen item,
  ) async {
    final db = await database;
    return db.insert(
      'info_pemanen',
      item.toMap(),
    );
  }

  Future<int> updateInfoPemanen(InfoPemanen item) async {
    final db = await database;
    return db.update('info_pemanen', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<int> deleteInfoPemanen(int id) async {
    final db = await database;
    return db.delete(
      'info_pemanen',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
