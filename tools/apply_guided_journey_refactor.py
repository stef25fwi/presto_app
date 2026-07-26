from __future__ import annotations

import base64
import gzip
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAYLOAD_DIR = ROOT / 'tools' / 'guided_payloads'


def decode_parts(glob_pattern: str) -> bytes:
    parts = sorted(PAYLOAD_DIR.glob(glob_pattern))
    if not parts:
        raise RuntimeError(f'Aucun payload trouvé pour {glob_pattern}')
    raw = ''.join(part.read_text(encoding='utf-8') for part in parts)
    return gzip.decompress(base64.b64decode(raw))


def write_payload(pattern: str, target: str) -> None:
    path = ROOT / target
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(decode_parts(pattern))


def patch_toolbox() -> None:
    path = ROOT / 'lib' / 'pages' / 'toolbox_je_me_lance_page.dart'
    source = path.read_text(encoding='utf-8')

    import_line = (
        "import 'package:presto_app/pages/account/guided_journey_page.dart';\n"
    )
    import_anchor = "import 'package:presto_app/pages/account_page.dart';\n"
    if import_line not in source:
        if import_anchor not in source:
            raise RuntimeError('Ancre import account_page introuvable')
        source = source.replace(import_anchor, import_anchor + import_line, 1)

    legacy_reference = (
        'const Type _legacyJourneySummaryRendererType = _JourneySummaryPage;\n\n'
    )
    legacy_anchor = "import '../services/region_resources_service.dart';\n\n"
    if legacy_reference not in source:
        if legacy_anchor not in source:
            raise RuntimeError('Ancre region resources introuvable')
        source = source.replace(
            legacy_anchor,
            legacy_anchor + legacy_reference,
            1,
        )

    source = source.replace(
        'builder: (_) => _JourneySummaryPage(',
        'builder: (_) => GuidedJourneyPage(',
    )
    source = source.replace(
        'return _JourneySummaryPage(',
        'return GuidedJourneyPage(',
    )

    assertion = (
        '    assert(_legacyJourneySummaryRendererType == _JourneySummaryPage);\n'
    )
    navigator_anchor = '    Navigator.of(context).push(\n'
    if assertion not in source:
        if navigator_anchor not in source:
            raise RuntimeError('Ancre Navigator introuvable')
        source = source.replace(
            navigator_anchor,
            assertion + navigator_anchor,
            1,
        )

    if 'GuidedJourneyPage(' not in source:
        raise RuntimeError('Le renderer guidé n’a pas été raccordé')

    path.write_text(source, encoding='utf-8')


def patch_pdf() -> None:
    path = ROOT / 'lib' / 'services' / 'journey_pdf_export_service.dart'
    source = path.read_text(encoding='utf-8')
    anchor = "    _appendTimeline(widgets, 'Étapes détaillées', journey['steps']);\n"
    line = (
        "    _appendMap(widgets, 'Progression guidée', "
        "journey['guidedProgress']);\n"
    )
    if line not in source:
        if anchor not in source:
            raise RuntimeError('Ancre PDF introuvable')
        source = source.replace(anchor, anchor + line, 1)
    path.write_text(source, encoding='utf-8')


def cleanup_payloads() -> None:
    shutil.rmtree(PAYLOAD_DIR)
    Path(__file__).unlink()


def main() -> None:
    write_payload(
        'guided_*.txt',
        'lib/pages/account/guided_journey_page.dart',
    )
    write_payload(
        'saved_*.txt',
        'lib/pages/account/saved_journey_summary_page.dart',
    )
    write_payload(
        'test_*.txt',
        'test/guided_journey_page_test.dart',
    )
    write_payload(
        'doc_*.txt',
        'docs/toolbox_guided_journey_implementation.md',
    )
    patch_toolbox()
    patch_pdf()
    cleanup_payloads()


if __name__ == '__main__':
    main()
