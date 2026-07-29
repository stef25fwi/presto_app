import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/pdf/ilipresto_pdf_branding.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('charge le logo WebP et les polices de l’entête PDF', () async {
    final branding = await IliprestoPdfBranding.load();

    expect(branding.logo, isNotNull);
    expect(branding.regularFont, isNotNull);
    expect(branding.boldFont, isNotNull);
    expect(IliprestoPdfBranding.logoAssetPath, endsWith('logowebp.webp'));
  });

  test('le texte juridique couvre responsabilité et organismes régionaux', () {
    expect(
      IliprestoPdfBranding.disclaimerText,
      contains('ne sauraient engager la responsabilité d’iliprestō'),
    );
    expect(
      IliprestoPdfBranding.disclaimerText,
      contains('organismes compétents de sa région'),
    );
  });
}
