import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/admin/widgets/admin_contact_mail_content.dart';

void main() {
  test('supprime la syntaxe Markdown des liens techniques Brevo', () {
    const raw =
        '[baifiddj.r.bh.d.sendibt3.com/tr/op/f1bgg...]'
        '(https://baifiddj.r.bh.d.sendibt3.com)\n\n'
        'Certification technique Brevo iliprestō.';

    expect(
      sanitizeAdminContactMailText(raw),
      'Certification technique Brevo iliprestō.',
    );
  });

  test('conserve le libellé humain d un lien Brevo tracké', () {
    const raw =
        '[Ouvrir iliprestō]'
        '(https://abc.r.bh.d.sendibt2.com/tr/click/123)';

    expect(sanitizeAdminContactMailText(raw), 'Ouvrir iliprestō');
  });

  test('conserve les URL métier normales', () {
    const raw = 'Site : https://ilipresto.fr';
    expect(sanitizeAdminContactMailText(raw), raw);
  });

  test('nettoie le HTML résiduel et les entités courantes', () {
    const raw = '<p>Bonjour &amp; bienvenue</p>';
    expect(sanitizeAdminContactMailText(raw), 'Bonjour & bienvenue');
  });

  test('aplatit le preview après nettoyage', () {
    const raw = 'Bonjour\n\n iliprestō';
    expect(
      sanitizeAdminContactMailPreview(raw, maxLength: 12),
      'Bonjour ilipr',
    );
  });
}
