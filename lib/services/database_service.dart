import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/tranche.dart';
import '../models/momo_transaction.dart';

/// Toutes les données sont stockées localement sur le téléphone via SQLite.
/// L'app fonctionne entièrement hors ligne : aucune de ces méthodes n'a
/// besoin de connexion internet. La synchronisation vers un serveur
/// (sauvegarde) sera ajoutée dans une étape séparée.
class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'carnet_momo.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tranches (
            id TEXT PRIMARY KEY,
            network TEXT NOT NULL,
            type TEXT NOT NULL,
            min_amount INTEGER NOT NULL,
            max_amount INTEGER NOT NULL,
            commission INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE transactions (
            id TEXT PRIMARY KEY,
            network TEXT NOT NULL,
            type TEXT NOT NULL,
            operation_number TEXT NOT NULL,
            montant INTEGER NOT NULL,
            commission INTEGER NOT NULL,
            date TEXT NOT NULL
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_transactions_network ON transactions(network)',
        );
        await db.execute(
          'CREATE INDEX idx_transactions_date ON transactions(date)',
        );
      },
    );
  }

  // ---------------- Tranches (grilles de commission) ----------------

  Future<List<Tranche>> getTranches(String network, String type) async {
    final db = await database;
    final rows = await db.query(
      'tranches',
      where: 'network = ? AND type = ?',
      whereArgs: [network, type],
      orderBy: 'min_amount ASC',
    );
    return rows.map((r) => Tranche.fromMap(r)).toList();
  }

  Future<void> upsertTranche(Tranche tranche) async {
    final db = await database;
    await db.insert(
      'tranches',
      tranche.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteTranche(String id) async {
    final db = await database;
    await db.delete('tranches', where: 'id = ?', whereArgs: [id]);
  }

  /// Trouve la commission applicable pour un montant donné.
  /// Retourne null si aucune tranche ne couvre ce montant.
  Future<int?> findCommission(String network, String type, int montant) async {
    final tranches = await getTranches(network, type);
    for (final t in tranches) {
      if (montant >= t.min && montant <= t.max) {
        return t.commission;
      }
    }
    return null;
  }

  // ---------------- Transactions ----------------

  Future<void> insertTransaction(MomoTransaction tx) async {
    final db = await database;
    await db.insert('transactions', tx.toMap());
  }

  /// Permet de corriger une opération mal saisie par erreur (mauvais
  /// montant, mauvais type, etc.) sans avoir à la supprimer et la
  /// recréer — la commission doit être recalculée par l'appelant avant
  /// d'appeler cette méthode, selon la grille en vigueur.
  Future<void> updateTransaction(MomoTransaction tx) async {
    final db = await database;
    await db.update('transactions', tx.toMap(), where: 'id = ?', whereArgs: [tx.id]);
  }

  Future<void> deleteTransaction(String id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MomoTransaction>> getTransactions({
    String? network,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (network != null) {
      conditions.add('network = ?');
      args.add(network);
    }
    if (from != null) {
      conditions.add('date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      conditions.add('date <= ?');
      args.add(to.toIso8601String());
    }

    final rows = await db.query(
      'transactions',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: conditions.isEmpty ? null : args,
      orderBy: 'date DESC',
    );
    return rows.map((r) => MomoTransaction.fromMap(r)).toList();
  }
}
