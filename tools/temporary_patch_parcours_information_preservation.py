#!/usr/bin/env python3

from pathlib import Path

SERVICE = Path('lib/services/parcours_fiches_service.dart')
PDF_SERVICE = Path('lib/services/journey_pdf_export_service.dart')
JSON_FICHE = Path('docs/menu_activite_statuts/pack_fiches_fonctionnaire_firebase/json/fonctionnaire_aide_demenagement.json')
MARKDOWN_FICHE = Path('docs/menu_activite_statuts/pack_fiches_fonctionnaire_firebase/markdown/fonctionnaire_aide_demenagement.md')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: {count} occurrence(s), 1 attendue')
    return text.replace(old, new, 1)


def patch_service() -> None:
    text = SERVICE.read_text(encoding='utf-8')

    text = replace_once(
        text,
        "    final regulationTutorial = _buildMarkdownRegulationTutorial();\n",
        """    final markdownRegulationTutorial = _buildMarkdownRegulationTutorial();
    final regulationTutorial = <Map<String, dynamic>>[
      ...(markdownRegulationTutorial.isNotEmpty
          ? markdownRegulationTutorial
          : generatedRegulationTutorial),
      if (markdownRegulationTutorial.isNotEmpty)
        for (final source in officialSources)
          <String, dynamic>{
            'title': 'Source officielle',
            'description': source,
          },
    ];
""",
        'construction du tutoriel réglementaire',
    )

    text = replace_once(
        text,
        """    final costs = <String, dynamic>{
      ...fallbackCosts,
      'formalitesEstimees': _estimateFormalites(recommendedStatus),
      'note': _buildCostNote(),
    };
""",
        """    final costs = <String, dynamic>{
      ...fallbackCosts,
      'formalitesEstimees': _estimateFormalites(recommendedStatus),
      'ficheCoutsIndicatifs': _dedupePreserveOrder([
        ...indicativeCosts,
        ..._buildFiscalityLines(),
      ]),
      'note': _buildCostNote(),
    };
""",
        'conservation des coûts et seuils',
    )

    text = replace_once(
        text,
        """      'regulationTutorial': regulationTutorial.isNotEmpty
          ? regulationTutorial
          : generatedRegulationTutorial,
""",
        """      'regulationTutorial': regulationTutorial,
""",
        'retour du tutoriel réglementaire',
    )

    text = replace_once(
        text,
        "          id: 'markdown_${index + 1}',\n",
        "          id: _canonicalMarkdownStepId(subsections[index].title, index),\n",
        'identifiants canoniques des étapes markdown',
    )

    marker = "  List<Map<String, dynamic>> _buildMarkdownAids() {\n"
    helper = """  String _canonicalMarkdownStepId(String title, int index) {
    final normalized = title.toLowerCase();
    if (normalized.contains('cumul') ||
        normalized.contains('situation personnelle')) {
      return 'situation';
    }
    if (normalized.contains('offre') ||
        normalized.contains('budget') ||
        normalized.contains('prix')) {
      return 'offres';
    }
    if (normalized.contains('aide')) {
      return 'aides';
    }
    if (normalized.contains('statut') || normalized.contains('cadre')) {
      return 'statut_lancement';
    }
    if (normalized.contains('dossier')) {
      return 'preparation';
    }
    if (normalized.contains('déclar') || normalized.contains('formalité')) {
      return 'declaration';
    }
    if (normalized.contains('protection') ||
        normalized.contains('assurance')) {
      return 'protections';
    }
    if (normalized.contains('gestion') ||
        normalized.contains('obligation récurrente')) {
      return 'gestion';
    }
    if (normalized.contains('lancer') ||
        normalized.contains('première offre') ||
        normalized.contains('premières offres')) {
      return 'lancement';
    }
    if (normalized.contains('activité') ||
        normalized.contains('règle') ||
        normalized.contains("droit d'exercer")) {
      return 'reglementation';
    }

    const fallbackIds = <String>[
      'reglementation',
      'situation',
      'offres',
      'aides',
      'statut_lancement',
      'preparation',
      'declaration',
      'protections',
      'gestion',
      'lancement',
    ];
    return index < fallbackIds.length
        ? fallbackIds[index]
        : 'markdown_${index + 1}';
  }

"""
    text = replace_once(text, marker, helper + marker, 'helper identifiants étapes')

    marker = "  String _buildCostNote() {\n"
    helper = """  List<String> _buildFiscalityLines() {
    const labels = <String, String>{
      'seuil_micro_service_2026': 'Seuil micro-fiscal prestations de services 2026',
      'cotisations_micro_bic_service_2026': 'Cotisations micro-sociales BIC services 2026',
      'tva_franchise_service_base_2026': 'Franchise en base de TVA - seuil',
      'tva_franchise_service_majore_2026': 'Franchise en base de TVA - seuil majoré',
      'tva_franchise_service_base': 'Franchise en base de TVA - seuil',
      'tva_franchise_service_majore': 'Franchise en base de TVA - seuil majoré',
      'compte_dedie': 'Compte bancaire dédié',
      'cfe': 'Cotisation foncière des entreprises',
    };
    final lines = <String>[];
    for (final entry in fiscality.entries) {
      final value = '${entry.value}'.trim();
      if (value.isEmpty) continue;
      final label = labels[entry.key] ?? entry.key.replaceAll('_', ' ');
      lines.add('$label : $value');
    }
    return _dedupePreserveOrder(lines);
  }

"""
    text = replace_once(text, marker, helper + marker, 'helper fiscalité')

    SERVICE.write_text(text, encoding='utf-8')


def patch_pdf_service() -> None:
    text = PDF_SERVICE.read_text(encoding='utf-8')
    text = replace_once(
        text,
        "    'gestion',\n  ];\n",
        "    'gestion',\n    'lancement',\n  ];\n",
        'ordre lancement PDF',
    )
    text = replace_once(
        text,
        "    'gestion': 'Organiser la gestion et les obligations récurrentes',\n  };\n",
        "    'gestion': 'Organiser la gestion et les obligations récurrentes',\n    'lancement': 'Lancer une première prestation maîtrisée',\n  };\n",
        'titre lancement PDF',
    )
    text = replace_once(
        text,
        """    'gestion':
        'Vous savez quoi suivre chaque mois ou trimestre et quelles échéances anticiper.',
  };
""",
        """    'gestion':
        'Vous savez quoi suivre chaque mois ou trimestre et quelles échéances anticiper.',
    'lancement':
        'La première mission reste limitée au périmètre autorisé, assuré et documenté.',
  };
""",
        'résultat lancement PDF',
    )
    PDF_SERVICE.write_text(text, encoding='utf-8')


def patch_json() -> None:
    text = JSON_FICHE.read_text(encoding='utf-8')
    text = text.replace('77 700 € de chiffre d\'affaires annuel', '83 600 € de chiffre d\'affaires annuel')
    text = replace_once(
        text,
        """    "Organisme compétent en transport si la prestation inclut le transport routier pour compte d'autrui"
""",
        """    "Service territorial de l'État compétent en transport (DEAL/DREAL) si la prestation inclut le transport routier pour compte d'autrui"
""",
        'organisme transport',
    )
    text = replace_once(
        text,
        """  "qualification_regles": "L'aide au déménagement est hors du périmètre des services à la personne. La manutention seule ne nécessite pas, par principe, de déclaration propre à ce secteur. Si la prestation comprend l'organisation d'un déménagement avec transport routier de biens pour le compte d'autrui, vérifier avant le lancement les obligations propres au transport et au déménagement, ainsi que la couverture des biens confiés.",
""",
        """  "qualification_regles": "L'aide au déménagement est hors du périmètre des services à la personne. La manutention seule ne nécessite pas, par principe, de déclaration propre à ce secteur. Si la prestation comprend un déménagement avec transport routier de biens pour le compte d'autrui, vérifier avant le lancement l'autorisation d'exercer, les exigences d'établissement, d'honorabilité, de capacité professionnelle et financière, l'inscription au registre électronique national des entreprises de transport par route et la licence adaptée. La couverture des biens confiés reste indispensable.",
""",
        'règles transport précises',
    )
    text = replace_once(
        text,
        """    "devis d'assurance correspondant au périmètre réel",
    "inventaire du matériel de manutention",
""",
        """    "devis d'assurance correspondant au périmètre réel",
    "justificatifs de capacité professionnelle et financière et licence lorsque le transport pour compte d'autrui est inclus",
    "inventaire du matériel de manutention",
""",
        'documents transport',
    )
    text = replace_once(
        text,
        """    "Ne pas transporter les biens d'un client sans avoir vérifié les obligations applicables et la couverture d'assurance",
""",
        """    "Ne pas transporter les biens d'un client pour compte d'autrui avant d'avoir vérifié l'autorisation d'exercer, l'inscription au registre, la licence, les capacités requises et la couverture d'assurance",
""",
        'alerte transport',
    )
    text = replace_once(
        text,
        """    "https://entreprendre.service-public.fr/vosdroits/F23267",
    "https://www.impots.gouv.fr/professionnel/tva"
""",
        """    "https://www.impots.gouv.fr/professionnel/questions/en-tant-que-micro-entrepreneur-sous-quelles-conditions-puis-je-opter-pour-l",
    "https://www.impots.gouv.fr/professionnel/tva",
    "https://www.legifrance.gouv.fr/codes/section_lc/LEGITEXT000023086525/LEGISCTA000033449959/",
    "https://www.legifrance.gouv.fr/codes/id/LEGISCTA000033450785"
""",
        'sources 2026 et transport',
    )
    JSON_FICHE.write_text(text, encoding='utf-8')


def patch_markdown() -> None:
    text = MARKDOWN_FICHE.read_text(encoding='utf-8')
    text = text.replace('77 700 €', '83 600 €')
    text = replace_once(
        text,
        """L’aide manuelle au chargement, au déchargement, à l’emballage ou au déplacement de mobilier sur un même site ne relève pas des services à la personne. Lorsque la prestation comprend un déménagement avec transport routier pour le compte du client, faites vérifier les obligations applicables avant toute publicité ou mission.

Le code APE 49.42Z correspond aux services de déménagement, mais le code définitif dépend de l’activité principale réellement déclarée et attribuée par l’Insee.
""",
        """L’aide manuelle au chargement, au déchargement, à l’emballage ou au déplacement de mobilier sur un même site ne relève pas des services à la personne. Lorsque la prestation comprend un déménagement avec transport routier de biens pour le compte d’autrui, vérifiez avant toute publicité ou mission l’autorisation d’exercer, les exigences d’établissement, d’honorabilité, de capacité professionnelle et financière, l’inscription au registre électronique national des entreprises de transport par route et la licence adaptée.

Le code APE 49.42Z correspond aux services de déménagement, mais le code définitif dépend de l’activité principale réellement déclarée et attribuée par l’Insee. L’assurance doit couvrir la manutention, les dommages aux locaux et les biens confiés ou transportés.
""",
        'markdown obligations transport',
    )
    text = replace_once(
        text,
        """* devis d’assurance ;
* estimation des revenus et de la périodicité ;
""",
        """* devis d’assurance ;
* justificatifs de capacité professionnelle et financière et licence si le transport pour compte d’autrui est inclus ;
* estimation des revenus et de la périodicité ;
""",
        'markdown documents transport',
    )
    text = replace_once(
        text,
        """* Le transport de biens peut imposer des vérifications supplémentaires.
""",
        """* Le transport de biens pour compte d’autrui peut imposer une autorisation d’exercer, des capacités professionnelle et financière, une inscription au registre et une licence.
""",
        'markdown limites transport',
    )
    text = replace_once(
        text,
        """Distinguez la manutention, l’emballage, le montage simple et le transport de biens. Définissez les exclusions et les objets que vous refusez de prendre en charge.
""",
        """Distinguez la manutention, l’emballage, le montage simple et le transport de biens. Définissez les exclusions et les objets refusés. Si le transport pour compte d’autrui est inclus, identifiez le service territorial compétent et les justificatifs d’autorisation, de capacité, d’inscription et de licence à obtenir.
""",
        'markdown étape réglementation',
    )
    text = replace_once(
        text,
        """* https://entreprendre.service-public.fr/vosdroits/F23267
* https://www.impots.gouv.fr/professionnel/tva
""",
        """* https://www.impots.gouv.fr/professionnel/questions/en-tant-que-micro-entrepreneur-sous-quelles-conditions-puis-je-opter-pour-l
* https://www.impots.gouv.fr/professionnel/tva
* https://www.legifrance.gouv.fr/codes/section_lc/LEGITEXT000023086525/LEGISCTA000033449959/
* https://www.legifrance.gouv.fr/codes/id/LEGISCTA000033450785
""",
        'markdown sources 2026 et transport',
    )
    MARKDOWN_FICHE.write_text(text, encoding='utf-8')


def main() -> None:
    patch_service()
    patch_pdf_service()
    patch_json()
    patch_markdown()


if __name__ == '__main__':
    main()
