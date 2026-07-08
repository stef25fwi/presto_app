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

    test("trouve une fiche demandeur d'emploi pour une activité du catalogue", () {
      final fiche = service.find(
        statutUtilisateur: "demandeur d'emploi",
        activite: 'Service en salle',
      );
      expect(fiche, isNotNull);
      expect(fiche!['statut_utilisateur'], 'demandeur d’emploi');
      expect(fiche['activite'], 'Service en salle');
      expect(fiche['regles_demandeur_emploi'], isA<Map>());
    });

    test('trouve une fiche sans activité pour une activité du catalogue', () {
      final fiche = service.find(
        statutUtilisateur: 'sans activité',
        activite: 'Service en salle',
      );
      expect(fiche, isNotNull);
      expect(fiche!['statut_utilisateur'], 'sans activité');
      expect(fiche['activite'], 'Service en salle');
      expect(fiche['regles_sans_activite'], isA<Map>());
    });

    test('les sept packs renvoient des fiches distinctes pour la même activité', () {
      const statuts = [
        'fonctionnaire',
        'retraité',
        'étudiant',
        'salarié',
        'indépendant',
        "demandeur d'emploi",
        'sans activité',
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

    test('retourne null pour un statut hors catalogue', () {
      final fiche = service.find(
        statutUtilisateur: 'extraterrestre',
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
