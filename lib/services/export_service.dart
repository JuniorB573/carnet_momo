import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/momo_transaction.dart';
import '../theme/networks.dart';
import 'formatters.dart';

/// Génère des rapports PDF (mensuel ou synthèse) et ouvre le menu de
/// partage du téléphone pour que l'agent puisse les envoyer ou les
/// sauvegarder (WhatsApp, email, etc.).
class ExportService {
  /// Génère un PDF mensuel complet : récapitulatif réseau par réseau
  /// (dépôt / retrait / sous-total) puis le journal chronologique de toutes
  /// les opérations du mois avec leurs détails complets.
  Future<void> exportMonth({
    required List<MomoTransaction> transactions,
    required int year,
    required int month,
  }) async {
    final monthTx = transactions
        .where((t) => t.date.year == year && t.date.month == month)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final doc = pw.Document();
    final monthDate = DateTime(year, month);
    final monthLabel = DateFormat('MMMM yyyy', 'fr_FR').format(monthDate);
    final now = DateTime.now();

    // ── Calculs du récapitulatif ──────────────────────────────────────────
    final networkIds = monthTx.map((t) => t.network).toSet().toList();
    final summaryRows = <List<String>>[];
    int grandMontant = 0;
    int grandCommission = 0;

    for (final netId in networkIds) {
      final netTxs = monthTx.where((t) => t.network == netId);
      final depots = netTxs.where((t) => t.type == 'depot');
      final retraits = netTxs.where((t) => t.type == 'retrait');

      final dM = depots.fold<int>(0, (a, t) => a + t.montant);
      final dC = depots.fold<int>(0, (a, t) => a + t.commission);
      final rM = retraits.fold<int>(0, (a, t) => a + t.montant);
      final rC = retraits.fold<int>(0, (a, t) => a + t.commission);
      final netM = dM + rM;
      final netC = dC + rC;

      final netLabel = kAllNetworks.firstWhere(
        (n) => n['id'] == netId,
        orElse: () => {'label': netId},
      )['label'] as String;

      summaryRows.add([netLabel, 'Dépôt', fmtF(dM), fmtF(dC)]);
      summaryRows.add(['', 'Retrait', fmtF(rM), fmtF(rC)]);
      summaryRows.add(['', 'Sous-total', fmtF(netM), fmtF(netC)]);

      grandMontant += netM;
      grandCommission += netC;
    }

    // ── Construction du PDF ───────────────────────────────────────────────
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Carnet MoMo — Rapport mensuel',
                  style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  monthLabel.toUpperCase(),
                  style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(now)}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.green800),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (ctx) => [
          // ── Section 1 : Récapitulatif ──────────────────────────────
          pw.Text('RÉCAPITULATIF', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
          pw.SizedBox(height: 8),
          if (summaryRows.isEmpty)
            pw.Text('Aucune opération ce mois.', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey))
          else ...[
            pw.TableHelper.fromTextArray(
              headers: ['Réseau', 'Type', 'Montant (F CFA)', 'Commission (F CFA)'],
              data: summaryRows,
              headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
              cellStyle: const pw.TextStyle(fontSize: 9),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.green50),
              cellAlignments: {
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              decoration: const pw.BoxDecoration(color: PdfColors.green800),
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL GÉNÉRAL',
                      style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  pw.Text('Montant : ${fmtF(grandMontant)}    Commission : ${fmtF(grandCommission)}',
                      style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                ],
              ),
            ),
          ],

          pw.SizedBox(height: 22),

          // ── Section 2 : Journal — Dépôts ──────────────────────────
          pw.Text('JOURNAL — DÉPÔTS', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
          pw.SizedBox(height: 8),
          if (monthTx.where((tx) => tx.type == 'depot').isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Text('Aucun dépôt ce mois.', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey)),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Heure', 'Réseau', 'N° Opération', 'Montant (F CFA)', 'Commission (F CFA)'],
              data: monthTx.where((tx) => tx.type == 'depot').map((tx) {
                final net = kAllNetworks.firstWhere(
                  (n) => n['id'] == tx.network,
                  orElse: () => {'label': tx.network},
                )['label'] as String;
                return [
                  DateFormat('dd/MM/yyyy').format(tx.date),
                  DateFormat('HH:mm').format(tx.date),
                  net,
                  tx.operationNumber,
                  fmtF(tx.montant),
                  fmtF(tx.commission),
                ];
              }).toList(),
              headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
              cellStyle: const pw.TextStyle(fontSize: 8),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.green50),
              cellAlignments: {
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            ),

          pw.SizedBox(height: 22),

          // ── Section 3 : Journal — Retraits ────────────────────────
          pw.Text('JOURNAL — RETRAITS', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.orange)),
          pw.SizedBox(height: 8),
          if (monthTx.where((tx) => tx.type == 'retrait').isEmpty)
            pw.Text('Aucun retrait ce mois.', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey))
          else
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Heure', 'Réseau', 'N° Opération', 'Montant (F CFA)', 'Commission (F CFA)'],
              data: monthTx.where((tx) => tx.type == 'retrait').map((tx) {
                final net = kAllNetworks.firstWhere(
                  (n) => n['id'] == tx.network,
                  orElse: () => {'label': tx.network},
                )['label'] as String;
                return [
                  DateFormat('dd/MM/yyyy').format(tx.date),
                  DateFormat('HH:mm').format(tx.date),
                  net,
                  tx.operationNumber,
                  fmtF(tx.montant),
                  fmtF(tx.commission),
                ];
              }).toList(),
              headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.orange),
              cellStyle: const pw.TextStyle(fontSize: 8),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.orange50),
              cellAlignments: {
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            ),
        ],
        footer: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Carnet MoMo · carnetmomo.app',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            ],
          ),
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final fileLabel = DateFormat('yyyy-MM').format(monthDate);
    final file = File('${dir.path}/carnet-momo-$fileLabel.pdf');
    await file.writeAsBytes(await doc.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Rapport MoMo — $monthLabel',
      text: 'Rapport mensuel Carnet MoMo pour $monthLabel',
    );
  }


  /// Génère un PDF du récapitulatif "Aujourd'hui" + "Ce mois" — réseau par
  /// réseau, dépôt à part, retrait à part, commission calculée pour
  /// chacun, puis le total général — et ouvre le menu de partage. Format
  /// PDF plutôt que CSV : plus lisible tel quel pour un partage direct
  /// (WhatsApp, email) sans avoir besoin d'ouvrir un tableur.
  Future<void> exportSummaryPdf({
    required List<MomoTransaction> today,
    required List<MomoTransaction> thisMonth,
    required String countryId,
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd').format(now);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Carnet MoMo — Synthèse',
                  style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  DateFormat('dd/MM/yyyy').format(now),
                  style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green800),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Générée le ${DateFormat('dd/MM/yyyy à HH:mm').format(now)}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.green800),
            pw.SizedBox(height: 8),
          ],
        ),
        build: (context) => [
          ..._buildSummarySectionPdf("AUJOURD'HUI", today, countryId),
          pw.SizedBox(height: 22),
          ..._buildSummarySectionPdf('CE MOIS', thisMonth, countryId),
        ],
        footer: (ctx) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Carnet MoMo · carnetmomo.app',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            ],
          ),
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/carnet-momo-synthese-$dateStr.pdf');
    await file.writeAsBytes(await doc.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Synthèse Carnet MoMo — $dateStr',
      text: 'Synthèse des opérations au $dateStr',
    );
  }

  /// Construit une section du PDF (Aujourd'hui ou Ce mois) : un tableau
  /// réseau par réseau avec dépôt et retrait sur des lignes séparées, la
  /// commission calculée pour chacun, puis le total général en bas.
  List<pw.Widget> _buildSummarySectionPdf(String title, List<MomoTransaction> txs, String countryId) {
    final widgets = <pw.Widget>[
      pw.Text(title, style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
    ];

    if (txs.isEmpty) {
      widgets.add(pw.Text('Aucune opération pour cette période.',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)));
      return widgets;
    }

    final countryNetworks = networksForCountry(countryId);
    final presentIds = txs.map((t) => t.network).toSet();
    final orderedNetworks = [
      ...countryNetworks.where((n) => presentIds.contains(n['id'])),
      ...kAllNetworks.where(
          (n) => presentIds.contains(n['id']) && !countryNetworks.any((cn) => cn['id'] == n['id'])),
    ];

    final rows = <List<String>>[];
    int grandMontant = 0;
    int grandCommission = 0;

    for (final network in orderedNetworks) {
      final netTxs = txs.where((t) => t.network == network['id']);
      final depots = netTxs.where((t) => t.type == 'depot');
      final retraits = netTxs.where((t) => t.type == 'retrait');

      final depotMontant = depots.fold<int>(0, (a, t) => a + t.montant);
      final depotCommission = depots.fold<int>(0, (a, t) => a + t.commission);
      final retraitMontant = retraits.fold<int>(0, (a, t) => a + t.montant);
      final retraitCommission = retraits.fold<int>(0, (a, t) => a + t.commission);
      final networkCommission = depotCommission + retraitCommission;

      rows.add([network['label'] as String, 'Dépôt', fmtF(depotMontant), fmtF(depotCommission)]);
      rows.add(['', 'Retrait', fmtF(retraitMontant), fmtF(retraitCommission)]);
      rows.add(['', 'Sous-total', fmtF(depotMontant + retraitMontant), fmtF(networkCommission)]);

      grandMontant += depotMontant + retraitMontant;
      grandCommission += networkCommission;
    }

    widgets.add(
      pw.TableHelper.fromTextArray(
        headers: ['Réseau', 'Type', 'Montant (F CFA)', 'Commission (F CFA)'],
        data: rows,
        headerStyle: const pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
        cellStyle: const pw.TextStyle(fontSize: 9),
        rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColors.green50),
        cellAlignments: {
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
        },
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      ),
    );

    widgets.add(pw.SizedBox(height: 6));
    widgets.add(
      pw.Container(
        decoration: const pw.BoxDecoration(color: PdfColors.green800),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('TOTAL GÉNÉRAL',
                style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            pw.Text('Montant : ${fmtF(grandMontant)}    Commission : ${fmtF(grandCommission)}',
                style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ],
        ),
      ),
    );

    return widgets;
  }

  /// Génère une fiche de rapport luxueuse pour un Kiosque / Agent (vue Propriétaire)
  /// Sauvegarde automatiquement le fichier PDF dans la mémoire interne (Documents / Téléchargements)
  /// et ouvre le dialogue de partage (WhatsApp, Email, etc.).
  Future<File> exportKioskReport({
    required String kioskName,
    required String agentPhone,
    required List<MomoTransaction> transactions,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();
    final cleanKioskName = kioskName.replaceAll(RegExp(r'[^\w\s\-]'), '').trim().replaceAll(' ', '_');

    // Filtre des transactions
    var txList = transactions.toList();
    if (fromDate != null) {
      txList = txList.where((t) => t.date.isAfter(fromDate) || t.date.isAtSameMomentAs(fromDate)).toList();
    }
    if (toDate != null) {
      txList = txList.where((t) => t.date.isBefore(toDate) || t.date.isAtSameMomentAs(toDate)).toList();
    }
    txList.sort((a, b) => b.date.compareTo(a.date));

    // Calculs
    int totalDepots = 0, totalRetraits = 0;
    int commDepots = 0, commRetraits = 0;
    int countDepots = 0, countRetraits = 0;

    for (final tx in txList) {
      if (tx.type == 'depot') {
        totalDepots += tx.montant;
        commDepots += tx.commission;
        countDepots++;
      } else {
        totalRetraits += tx.montant;
        commRetraits += tx.commission;
        countRetraits++;
      }
    }

    final totalMontant = totalDepots + totalRetraits;
    final totalCommission = commDepots + commRetraits;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('CARNET MOMO · FICHE PROPRIÉTAIRE',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                    pw.SizedBox(height: 2),
                    pw.Text(kioskName.toUpperCase(),
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                    pw.Text('Agent : $agentPhone',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green800,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text('RAPPORT D’ACTIVITÉ',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Date d’émission : ${DateFormat('dd/MM/yyyy HH:mm').format(now)}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                pw.Text('Total : ${txList.length} opérations',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
            pw.Divider(thickness: 1.5, color: PdfColors.green800),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (ctx) => [
          // ── Bloc des cartes résumées ──────────────────────────────
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.green700, width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TOTAL DÉPÔTS ($countDepots)',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                      pw.SizedBox(height: 4),
                      pw.Text(fmtF(totalDepots),
                          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                      pw.Text('Comm. : ${fmtF(commDepots)}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.orange50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.orange700, width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('TOTAL RETRAITS ($countRetraits)',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                      pw.SizedBox(height: 4),
                      pw.Text(fmtF(totalRetraits),
                          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                      pw.Text('Comm. : ${fmtF(commRetraits)}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey600, width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('COMMISSIONS GÉNÉRÉES',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                      pw.SizedBox(height: 4),
                      pw.Text(fmtF(totalCommission),
                          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                      pw.Text('Volume : ${fmtF(totalMontant)}',
                          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // ── Tableau des opérations ────────────────────────────────
          pw.Text('JOURNAL DÉTAILLÉ DES TRANSACTIONS',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
          pw.SizedBox(height: 8),

          if (txList.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 20),
              child: pw.Center(
                child: pw.Text('Aucune transaction enregistrée pour cette période.',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: ['Date & Heure', 'Réseau', 'Type', 'N° Opération', 'Client', 'Montant', 'Commission'],
              data: txList.map((tx) {
                final net = kAllNetworks.firstWhere((n) => n['id'] == tx.network, orElse: () => {'label': tx.network});
                return [
                  DateFormat('dd/MM HH:mm').format(tx.date),
                  net['label'] as String,
                  tx.type == 'depot' ? 'Dépôt' : 'Retrait',
                  tx.operationNumber,
                  tx.clientName ?? '—',
                  fmtF(tx.montant),
                  fmtF(tx.commission),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.green900),
              cellStyle: const pw.TextStyle(fontSize: 8),
              rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              cellAlignments: {
                5: pw.Alignment.centerRight,
                6: pw.Alignment.centerRight,
              },
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            ),
        ],
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Fiche certifiée générée par Carnet MoMo · Propriétaire : $kioskName',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        ),
      ),
    );

    // Sauvegarde dans la mémoire interne (Documents / App Documents)
    Directory? storageDir;
    try {
      storageDir = await getExternalStorageDirectory();
    } catch (_) {}
    storageDir ??= await getApplicationDocumentsDirectory();

    final dateTag = DateFormat('yyyy-MM-dd_HHmm').format(now);
    final fileName = 'Fiche_${cleanKioskName}_$dateTag.pdf';
    final savedFile = File('${storageDir.path}/$fileName');
    await savedFile.writeAsBytes(await doc.save());

    // Partager via WhatsApp / Email / etc.
    await Share.shareXFiles(
      [XFile(savedFile.path)],
      subject: 'Fiche MoMo — $kioskName',
    );

    return savedFile;
  }
}
