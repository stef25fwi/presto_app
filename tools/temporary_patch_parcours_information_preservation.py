#!/usr/bin/env python3

from pathlib import Path

PATH = Path('lib/services/parcours_fiches_service.dart')


def main() -> None:
    text = PATH.read_text(encoding='utf-8')
    old = """    if (normalized.contains('offre') ||
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
    if (normalized.contains('protection') || normalized.contains('assurance')) {
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
"""
    new = """    if (normalized.contains('lancer') ||
        normalized.contains('première offre') ||
        normalized.contains('premières offres')) {
      return 'lancement';
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
    if (normalized.contains('protection') || normalized.contains('assurance')) {
      return 'protections';
    }
    if (normalized.contains('gestion') ||
        normalized.contains('obligation récurrente')) {
      return 'gestion';
    }
"""
    if text.count(old) != 1:
      raise RuntimeError('Bloc de mapping des étapes introuvable ou ambigu')
    PATH.write_text(text.replace(old, new, 1), encoding='utf-8')


if __name__ == '__main__':
    main()
