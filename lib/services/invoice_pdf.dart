import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

String _money(num v) => v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

/// Накладная A5 — как в прежней версии программы, плюс картинка комнаты из 3D.
/// Данные приходят из конструктора (кнопка «Печать накладной»).
class InvoicePdf {
  static Future<Uint8List> build(Map<String, dynamic> d) async {
    // шрифт с кириллицей внутри программы — печать работает без интернета
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
    final cur = (d['currency'] ?? 'сум') as String;
    final shop = (d['shop'] ?? '3D Kamron') as String;
    pw.MemoryImage? picture;
    final img = d['image'] as String? ?? '';
    final comma = img.indexOf(',');
    if (img.startsWith('data:image') && comma > 0) picture = pw.MemoryImage(base64Decode(img.substring(comma + 1)));

    final materials = (d['materials'] as List? ?? const []).cast<Map>();
    final items = (d['items'] as List? ?? const []).cast<Map>();
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: const PdfPageFormat(210 * PdfPageFormat.mm, 148 * PdfPageFormat.mm),
      margin: const pw.EdgeInsets.all(12),
      build: (ctx) => pw.Theme(
        data: pw.ThemeData.withFont(base: font, bold: bold),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('НАКЛАДНАЯ', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.Text(shop, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('${d['phone'] ?? ''}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('${d['address'] ?? ''}', style: const pw.TextStyle(fontSize: 9)),
              pw.Text('№ ${d['number'] ?? ''} · ${d['date'] ?? ''}', style: const pw.TextStyle(fontSize: 8)),
            ]),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (picture != null)
              pw.Container(
                width: 150,
                height: 112,
                margin: const pw.EdgeInsets.only(right: 10),
                child: pw.Image(picture, fit: pw.BoxFit.cover),
              ),
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Размеры помещения: ${d['dims'] ?? ''}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                pw.Text('${d['grout'] ?? ''}', style: const pw.TextStyle(fontSize: 8)),
                pw.Divider(height: 8),
                pw.Text('ВЫБРАННЫЕ МАТЕРИАЛЫ:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 2),
                for (final m in materials)
                  pw.Text('• ${m['label']}: ${m['name']} (${m['size']} см) — ${_money(m['price'] as num? ?? 0)} $cur/м²',
                      style: const pw.TextStyle(fontSize: 7.5)),
              ]),
            ),
          ]),
          pw.SizedBox(height: 6),
          pw.Text('ИТОГОВЫЙ РАСЧЁТ:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 2),
          for (final i in items)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 1),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Expanded(
                  child: pw.Text('${i['name']} (${i['pieces']} шт. / ${i['boxes']} кор. / ${(i['area'] as num? ?? 0).toStringAsFixed(2)} м²)',
                      style: const pw.TextStyle(fontSize: 7.5)),
                ),
                pw.Text('${_money(i['sum'] as num? ?? 0)} $cur', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
              ]),
            ),
          pw.Spacer(),
          pw.Divider(height: 8),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('ИТОГО К ОПЛАТЕ:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text('${_money(d['total'] as num? ?? 0)} $cur', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ]),
          pw.SizedBox(height: 3),
          pw.Center(child: pw.Text('Спасибо за выбор $shop!', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700))),
        ]),
      ),
    ));
    return doc.save();
  }

  /// Открывает системное окно печати Windows (можно выбрать принтер или «Сохранить как PDF»).
  static Future<void> printInvoice(Map<String, dynamic> d) async {
    final bytes = await build(d);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'Nakladnaya_${d['shop'] ?? '3D_Kamron'}_${d['number'] ?? ''}'.replaceAll(' ', '_'));
  }
}
