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

    test('trouve une fiche indépendant pour une activité du catalogue', () {
      final fiche = service.find(
        statutUtilisateur: 'indépendant',
        activite: 'Service en salle',
      );
      expect(fiche, isNotNull);
      expect(fiche!['statut_utilisateur'], 'indépendant');
      expect(fiche['activite'], 'Service en salle');
      expect(fiche['regles_independant'], isA<Map>());
    });

    test('les cinq packs renvoient des fiches distinctes pour la même activité', () {
      const statuts = [
        'fonctionnaire',
        'retraité',
        'étudiant',
        'salarié',
        'indépendant',
      ];
      final ids = <Object>{};
      for (final statut in statuts) {
        final fiche = service.find(
          statutUtilisateur: statut,
          activite: 'Tonte de pelouse',
        );
        expect(fiche, isNotNull, reason: 'statut $statut');
        ids.add(fiche!['id_fiche']);
      }
      expect(ids, hasLength(statuts.length));
    });

    test('la normalisation ignore accents/casse sur le statut', () {
      final fiche = service.find(
        statutUtilisateur: 'Retraité',
        activite: 'service en salle',
      );
      expect(fiche, isNotNull);
    });

    test('retourne null pour un statut sans pack (ex. sans activité)', () {
      final fiche = service.find(
        statutUtilisateur: 'sans activité',
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
