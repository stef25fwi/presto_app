import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class IliprestoPdfBranding {
  const IliprestoPdfBranding._({
    required this.logo,
    required this.regularFont,
    required this.boldFont,
  });

  static const logoAssetPath = 'assets/images/logowebp.webp';
  static const regularFontAssetPath = 'assets/fonts/Inter-Regular.ttf';
  static const boldFontAssetPath = 'assets/fonts/Inter-Bold.ttf';
  static final PdfColor orange = PdfColor.fromHex('#FF6600');

  static const disclaimerText =
      'Les informations présentées dans ce document sont fournies à titre '
      'strictement indicatif et ne sauraient engager la responsabilité '
      'd’iliprestō. L’utilisateur doit, en complément, se rapprocher des '
      'organismes compétents de sa région afin de vérifier les démarches, '
      'règles, montants et obligations applicables à sa situation.';

  final pw.MemoryImage logo;
  final pw.Font regularFont;
  final pw.Font boldFont;

  static Future<IliprestoPdfBranding> load() async {
    final logoData = await rootBundle.load(logoAssetPath);
    final regularData = await rootBundle.load(regularFontAssetPath);
    final boldData = await rootBundle.load(boldFontAssetPath);
    return IliprestoPdfBranding._(
      logo: pw.MemoryImage(logoData.buffer.asUint8List()),
      regularFont: pw.Font.ttf(regularData),
      boldFont: pw.Font.ttf(boldData),
    );
  }

  pw.ThemeData get theme => pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      );

  pw.Widget header({required String documentTitle}) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.7),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Image(logo, width: 30, height: 30, fit: pw.BoxFit.contain),
          pw.SizedBox(width: 9),
          pw.Text(
            'iliprestō',
            style: pw.TextStyle(
              fontSize: 17,
              fontWeight: pw.FontWeight.bold,
              color: orange,
            ),
          ),
          pw.Spacer(),
          pw.ConstrainedBox(
            constraints: const pw.BoxConstraints(maxWidth: 260),
            child: pw.Text(
              documentTitle,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget footer(pw.Context context) {
    return pw.Row(
      children: [
        pw.Text(
          'Document généré par iliprestō',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.Spacer(),
        pw.Text(
          'Page ${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    );
  }

  pw.Widget disclaimer({String? additionalText}) {
    final text = additionalText == null || additionalText.trim().isEmpty
        ? disclaimerText
        : '$additionalText\n\n$disclaimerText';
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 18),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange50,
        border: pw.Border.all(color: PdfColors.orange200, width: 0.7),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(
          fontSize: 8.5,
          lineSpacing: 2,
          color: PdfColors.grey800,
        ),
      ),
    );
  }
}
