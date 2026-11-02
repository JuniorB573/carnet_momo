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
      version: 2,
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
            client_name TEXT,
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
        await db.execute(
          'CREATE INDEX idx_transactions_op_number ON transactions(operation_number)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute('ALTER TABLE transactions ADD COLUMN client_name TEXT');
          } catch (_) {}
          try {
            await db.execute('CREATE INDEX idx_transactions_op_number ON transactions(operation_number)');
          } catch (_) {}
        }
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

  /// Efface toutes les transactions et toutes les tranches de la base locale.
  /// Appelé lors de la déconnexion pour garantir que les données d'un compte
  /// ne sont jamais visibles par un autre compte connecté sur le même appareil.
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('tranches');
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

  /// Recherche un client déjà enregistré avec ce numéro :
  /// Renvoie un enregistrement avec le nom mémorisé et le nombre d'opérations passées.
  Future<Map<String, dynamic>?> lookupClientByNumber(String operationNumber) async {
    final clean = operationNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.length < 6) return null;

    final db = await database;
    // On cherche d'abord s'il y a un nom enregistré
    final rowsWithName = await db.query(
      'transactions',
      columns: ['client_name', 'date', 'type', 'montant'],
      where: "REPLACE(REPLACE(REPLACE(operation_number, ' ', ''), '-', ''), '+', '') LIKE ? AND client_name IS NOT NULL AND client_name != ''",
      whereArgs: ['%$clean%'],
      orderBy: 'date DESC',
      limit: 1,
    );

    final totalCountResult = await db.rawQuery('''
      SELECT COUNT(*) as count, MAX(date) as last_date
      FROM transactions
      WHERE REPLACE(REPLACE(REPLACE(operation_number, ' ', ''), '-', ''), '+', '') LIKE ?
    ''', ['%$clean%']);

    final count = Sqflite.firstIntValue(totalCountResult) ?? 0;
    if (count == 0) return null;

    final String? clientName = rowsWithName.isNotEmpty ? rowsWithName.first['client_name'] as String? : null;
    return {
      'count': count,
      'client_name': clientName,
      'last_tx': rowsWithName.isNotEmpty ? rowsWithName.first : null,
    };
  }
}

