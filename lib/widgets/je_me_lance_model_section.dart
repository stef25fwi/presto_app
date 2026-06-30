import 'package:flutter/material.dart';

class JeMeLanceModelSection extends StatelessWidget {
  const JeMeLanceModelSection({super.key});

  static const Color _orange = Color(0xFFFF6600);
  static const Color _blue = Color(0xFF1A73E8);
  static const Color _softBg = Color(0xFFFFF7F0);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        _IntroCard(),
        SizedBox(height: 14),
        _FlowSchemaCard(),
        SizedBox(height: 14),
        _FieldsTableCard(),
        SizedBox(height: 14),
        _ProfileBranchesCard(),
        SizedBox(height: 14),
        _FunctionnaireSnackCaseCard(),
        SizedBox(height: 14),
        _UrssafComparisonCard(),
        SizedBox(height: 14),
        _FinalOutputCard(),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Je me lance',
      icon: Icons.rocket_launch_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _InfoText(
            'Assistant de création d’activité : le parcours analyse le profil, le projet, les contraintes légales, puis propose un plan personnalisé avant comparaison avec les estimations Urssaf / Mon-entreprise.',
          ),
          SizedBox(height: 10),
          _WarningBox(
            text:
                'Important : l’Urssaf / Mon-entreprise sert surtout à estimer les cotisations, le revenu net et l’impôt. Le dépôt officiel de création se fait ensuite via le Guichet unique.',
          ),
        ],
      ),
    );
  }
}

class _FlowSchemaCard extends StatelessWidget {
  const _FlowSchemaCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Schéma du parcours',
      icon: Icons.account_tree_rounded,
      child: Column(
        children: const [
          _FlowStep(
              number: '1',
              title: 'Profil personnel',
              details:
                  'Fonctionnaire, salarié, demandeur d’emploi, étudiant, retraité, sans activité.'),
          _FlowStep(
              number: '2',
              title: 'Projet',
              details:
                  'Activité, lieu, budget, seul ou associé, local, domicile, marché, en ligne.'),
          _FlowStep(
              number: '3',
              title: 'Contrôles automatiques',
              details:
                  'Activité réglementée, autorisation employeur, conflit d’intérêts, formation, licence, déclaration sanitaire.'),
          _FlowStep(
              number: '4',
              title: 'Statuts proposés',
              details:
                  'Micro-entreprise, EI, EURL, SASU, SARL, SAS selon le projet.'),
          _FlowStep(
              number: '5',
              title: 'Comparaison Urssaf',
              details:
                  'Cotisations, revenu net, impôt, simulation micro / EI / SASU / EURL.'),
          _FlowStep(
              number: '6',
              title: 'Plan personnalisé',
              details:
                  'Démarches, documents, contacts, checklist, plan d’action 30 jours.'),
        ],
      ),
    );
  }
}

class _FieldsTableCard extends StatelessWidget {
  const _FieldsTableCard();

  @override
  Widget build(BuildContext context) {
    final rows = <_TableRowData>[
      _TableRowData(
          'Profil utilisateur',
          'Âge, commune, région, situation actuelle',
          'Détermine les contraintes de départ'),
      _TableRowData(
          'Situation professionnelle',
          'Fonctionnaire, salarié, demandeur d’emploi, étudiant, retraité',
          'Déclenche les règles spécifiques'),
      _TableRowData(
          'Fonctionnaire',
          'Fonction publique, temps complet, poste sensible, employeur',
          'Vérifie autorisation, déclaration, conflit d’intérêts'),
      _TableRowData(
          'Projet',
          'Nom, description, activité principale et secondaire',
          'Qualifie l’activité'),
      _TableRowData(
          'Type d’activité',
          'Vente, service, artisanat, restauration, transport, numérique',
          'Détermine statut et obligations'),
      _TableRowData(
          'Lieu',
          'Domicile, local, marché, véhicule, en ligne, chez client',
          'Détermine mairie, bail, ERP, assurance'),
      _TableRowData(
          'Clientèle',
          'Particuliers, entreprises, collectivités, touristes',
          'Repère les obligations supplémentaires'),
      _TableRowData('Financier', 'CA prévu, charges, stock, local, salarié',
          'Compare micro, EI, société'),
      _TableRowData(
          'Réglementaire',
          'Alcool, denrées animales, diplôme, assurance',
          'Déclenche alertes et démarches'),
      _TableRowData(
          'Sortie',
          'Statut conseillé, risque, démarches, coût, calendrier',
          'Produit le plan final'),
    ];

    return _SectionCard(
      title: 'Champs proposés',
      icon: Icons.view_list_rounded,
      child: Column(
        children: rows
            .map(
              (row) => _MiniTableRow(
                title: row.title,
                fields: row.fields,
                purpose: row.purpose,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ProfileBranchesCard extends StatelessWidget {
  const _ProfileBranchesCard();

  @override
  Widget build(BuildContext context) {
    final rows = <_TableRowData>[
      _TableRowData(
          'Fonctionnaire',
          'Temps complet, temps partiel, activité accessoire, conflit d’intérêts',
          'Autorisation écrite, déclaration, avis déontologue si doute'),
      _TableRowData(
          'Salarié privé',
          'Clause d’exclusivité, non-concurrence, loyauté employeur',
          'Vérifier contrat avant création'),
      _TableRowData(
          'Demandeur d’emploi',
          'ARE, ARCE, ACRE, maintien allocations',
          'Comparer maintien ARE ou capital ARCE'),
      _TableRowData(
          'Étudiant',
          'Mineur/majeur, foyer fiscal, activité faible volume',
          'Micro-entreprise possible si compatible'),
      _TableRowData(
          'Retraité',
          'Cumul emploi-retraite, plafond éventuel, fiscalité',
          'Créer activité secondaire avec vigilance'),
      _TableRowData(
          'Sans activité',
          'Besoin revenu rapide, aides locales, accompagnement',
          'Parcours création + financement'),
      _TableRowData(
          'Déjà entrepreneur',
          'Ajout activité, modification INPI, plafonds micro',
          'Modifier plutôt que recréer'),
    ];

    return _SectionCard(
      title: 'Ramifications par profil',
      icon: Icons.hub_rounded,
      child: Column(
        children: rows
            .map(
              (row) => _MiniTableRow(
                title: row.title,
                fields: row.fields,
                purpose: row.purpose,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _FunctionnaireSnackCaseCard extends StatelessWidget {
  const _FunctionnaireSnackCaseCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Exemple : fonctionnaire qui veut créer un snack',
      icon: Icons.lunch_dining_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _StatusPill(
              label: 'Verdict',
              value: 'Projet possible mais soumis à validation préalable',
              color: Color(0xFFFF9800)),
          SizedBox(height: 10),
          _MiniTableRow(
            title: '1. Alerte fonctionnaire',
            fields: 'Agent public à temps complet ou partiel',
            purpose:
                'Demander l’autorisation écrite avant toute immatriculation',
          ),
          _MiniTableRow(
            title: '2. Qualification activité',
            fields: 'Snack, restauration rapide, vente à emporter ou sur place',
            purpose: 'Activité commerciale structurée',
          ),
          _MiniTableRow(
            title: '3. Risque juridique',
            fields: 'Horaires, stock, clientèle régulière, local',
            purpose: 'Vérifier activité accessoire ou demande de temps partiel',
          ),
          _MiniTableRow(
            title: '4. Statut conseillé',
            fields:
                'Micro pour test limité ; EI réel, EURL ou SASU si charges/local',
            purpose: 'Adapter le statut au volume et aux investissements',
          ),
          _MiniTableRow(
            title: '5. Démarches métier',
            fields:
                'Hygiène alimentaire, déclaration sanitaire, assurance, licence si alcool',
            purpose: 'Sécuriser l’ouverture du snack',
          ),
          _MiniTableRow(
            title: '6. Démarches officielles',
            fields: 'Guichet unique, SIRET, obligations fiscales et sociales',
            purpose: 'Créer officiellement l’activité après validation',
          ),
        ],
      ),
    );
  }
}

class _UrssafComparisonCard extends StatelessWidget {
  const _UrssafComparisonCard();

  @override
  Widget build(BuildContext context) {
    final rows = <_TableRowData>[
      _TableRowData(
          'Point de départ',
          'Notre app : profil + projet + contraintes',
          'Urssaf : statut + chiffre d’affaires'),
      _TableRowData(
          'Fonctionnaire',
          'Notre app : autorisation, conflit d’intérêts, temps partiel',
          'Urssaf : pas le cœur du calcul'),
      _TableRowData(
          'Snack',
          'Notre app : hygiène, DAAF, licence, local, assurance',
          'Urssaf : non ou indirect'),
      _TableRowData('Choix statut', 'Notre app : recommandation contextualisée',
          'Urssaf : comparaison économique'),
      _TableRowData('Cotisations', 'Notre app : affiche l’estimation',
          'Urssaf : moteur de calcul fiable'),
      _TableRowData('Démarches locales',
          'Notre app : mairie, DAAF, CCI/CMA, assurance', 'Urssaf : non'),
      _TableRowData(
          'Valeur ajoutée',
          'Notre app : guide, filtre, alerte, prépare',
          'Urssaf : chiffre et vérifie'),
    ];

    return _SectionCard(
      title: 'Comparaison avec Urssaf / Mon-entreprise',
      icon: Icons.compare_arrows_rounded,
      child: Column(
        children: rows
            .map(
              (row) => _MiniTableRow(
                title: row.title,
                fields: row.fields,
                purpose: row.purpose,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _FinalOutputCard extends StatelessWidget {
  const _FinalOutputCard();

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Sortie finale affichée à l’utilisateur',
      icon: Icons.fact_check_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _StatusPill(
              label: 'Niveau de risque',
              value: 'Orange tant que l’autorisation n’est pas obtenue',
              color: Color(0xFFFF9800)),
          SizedBox(height: 10),
          _ChecklistItem(
              'Statut recommandé : micro pour test limité, EI/EURL/SASU si charges importantes.'),
          _ChecklistItem(
              'Démarches avant création : autorisation hiérarchique, contrôle conflit d’intérêts, budget.'),
          _ChecklistItem(
              'Démarches métier : hygiène alimentaire, déclaration DAAF, licence si alcool, assurance.'),
          _ChecklistItem(
              'Démarches officielles : Guichet unique, SIRET, obligations sociales et fiscales.'),
          _ChecklistItem(
              'Comparaison Urssaf : simulation micro / EI / SASU / EURL avec chiffre d’affaires prévu.'),
          _ChecklistItem(
              'Documents générés : checklist, courrier d’autorisation, tableau de coûts, plan d’action 30 jours.'),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: JeMeLanceModelSection._softBg,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: JeMeLanceModelSection._orange.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor:
                    JeMeLanceModelSection._orange.withOpacity(0.14),
                child:
                    Icon(icon, color: JeMeLanceModelSection._orange, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF202124),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final String number;
  final String title;
  final String details;

  const _FlowStep({
    required this.number,
    required this.title,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: JeMeLanceModelSection._blue,
            child: Text(
              number,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.only(bottom: 10),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFEAEAEA)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(details,
                      style: const TextStyle(
                          height: 1.35, color: Color(0xFF5F6368))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTableRow extends StatelessWidget {
  final String title;
  final String fields;
  final String purpose;

  const _MiniTableRow({
    required this.title,
    required this.fields,
    required this.purpose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 5),
          Text(fields,
              style: const TextStyle(color: Color(0xFF3C4043), height: 1.35)),
          const SizedBox(height: 4),
          Text(
            purpose,
            style: const TextStyle(
              color: Color(0xFF5F6368),
              height: 1.35,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBox extends StatelessWidget {
  final String text;

  const _WarningBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFE65100), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF5D4037), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Color(0xFF202124), height: 1.35),
          children: [
            TextSpan(
                text: '$label : ',
                style: const TextStyle(fontWeight: FontWeight.w900)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final String text;

  const _ChecklistItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded,
              color: JeMeLanceModelSection._blue, size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _InfoText extends StatelessWidget {
  final String text;

  const _InfoText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        height: 1.4,
        color: Color(0xFF3C4043),
      ),
    );
  }
}

class _TableRowData {
  final String title;
  final String fields;
  final String purpose;

  const _TableRowData(this.title, this.fields, this.purpose);
}
