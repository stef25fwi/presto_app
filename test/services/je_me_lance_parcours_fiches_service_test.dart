import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/services/je_me_lance_parcours_fiches_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JeMeLanceParcoursFichesService', () {
    late JeMeLanceParcoursFichesService service;

    setUpAll(() async {
      service = JeMeLanceParcoursFichesService.instance;
      await service.ensureLoaded();
    });

    test('trouve une fiche fonctionnaire pour une activité du catalogue', () {
      final fiche = service.find(
        statutUtilisateur: 'fonctionnaire',
        activite: 'Service en salle',
      );
      expect(fiche, isNotNull);
      expect(fiche!['statut_utilisateur'], 'fonctionnaire');
      expect(fiche['activite'], 'Service en salle');
    });

    test('trouve une fiche retraité pour une activité du catalogue', () {
      final fiche = service.find(
        statutUtilisateur: 'retraité',
        activite: 'Service en salle',
      );
      expect(fiche, isNotNull);
      expect(fiche!['statut_utilisateur'], 'retraité');
      expect(fiche['activite'], 'Service en salle');
    });

    test('trouve une fiche étudiant pour une activité du catalogue', () {
      final fiche = service.find(
        statutUtilisateur: 'étudiant',
        activite: 'Service en salle',
      );
      expect(fiche, isNotNull);
      expect(fiche!['statut_utilisateur'], 'étudiant');
      expect(fiche['activite'], 'Service en salle');
      expect(fiche['regles_etudiant'], isA<Map>());
    });

    test('trouve une fiche salarié pour une activité du catalogue', () {
      final fiche = service.find(
        statutUtilisateur: 'salarié',
        activite: 'Service en salle',
      );
      expect(fiche, isNotNull);
      expect(fiche!['statut_utilisateur'], 'salarié');
      expect(fiche['activite'], 'Service en salle');
      expect(fiche['regles_salarie'], isA<Map>());
    });

    test('les quatre packs renvoient des fiches distinctes pour la même activité', () {
      final fonctionnaire = service.find(
        statutUtilisateur: 'fonctionnaire',
        activite: 'Tonte de pelouse',
      );
      final retraite = service.find(
        statutUtilisateur: 'retraité',
        activite: 'Tonte de pelouse',
      );
      final etudiant = service.find(
        statutUtilisateur: 'étudiant',
        activite: 'Tonte de pelouse',
      );
      final salarie = service.find(
        statutUtilisateur: 'salarié',
        activite: 'Tonte de pelouse',
      );
      expect(fonctionnaire, isNotNull);
      expect(retraite, isNotNull);
      expect(etudiant, isNotNull);
      expect(salarie, isNotNull);
      final ids = {
        fonctionnaire!['id_fiche'],
        retraite!['id_fiche'],
        etudiant!['id_fiche'],
        salarie!['id_fiche'],
      };
      expect(ids, hasLength(4));
    });

    test('la normalisation ignore accents/casse sur le statut', () {
      final fiche = service.find(
        statutUtilisateur: 'Retraité',
        activite: 'service en salle',
      );
      expect(fiche, isNotNull);
    });

    test('retourne null pour un statut sans pack (ex. indépendant)', () {
      final fiche = service.find(
        statutUtilisateur: 'indépendant',
        activite: 'Service en salle',
      );
      expect(fiche, isNull);
    });

    test('retourne null pour une activité inconnue', () {
      final fiche = service.find(
        statutUtilisateur: 'fonctionnaire',
        activite: 'Activité inexistante',
      );
      expect(fiche, isNull);
    });
  });
}
