from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / 'lib/pages/toolbox_je_me_lance_page.dart'

source = TARGET.read_text(encoding='utf-8')

source = source.replace(
    '// toolbox_je_me_lance_page.dart',
    '// ignore_for_file: unused_element',
    1,
)
source = source.replace(
    'const Type _legacyJourneySummaryRendererType = _JourneySummaryPage;\n\n',
    '',
    1,
)
source = source.replace(
    '    assert(_legacyJourneySummaryRendererType == _JourneySummaryPage);\n',
    '',
    1,
)
source = source.replace(
    '// © You can freely adapt.\n\nimport \'dart:async\';',
    '// © You can freely adapt.\nimport \'dart:async\';',
    1,
)

if 'GuidedJourneyPage(' not in source:
    raise RuntimeError('Le renderer guidé n’est plus raccordé au parcours.')
if '_legacyJourneySummaryRendererType' in source:
    raise RuntimeError('La référence temporaire au renderer historique subsiste.')
if not source.startswith('// ignore_for_file: unused_element'):
    raise RuntimeError('La directive de compatibilité du renderer historique manque.')

TARGET.write_text(source, encoding='utf-8')
Path(__file__).unlink()
