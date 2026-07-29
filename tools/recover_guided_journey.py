from pathlib import Path
import subprocess

SOURCE = "origin/feat/guided-personal-journey"

COPY_FILES = [
    "docs/toolbox_guided_journey_implementation.md",
    "lib/features/guided_journey/guided_journey_models.dart",
    "lib/features/guided_journey/guided_journey_visible_content.dart",
    "lib/features/guided_journey/widgets/guided_journey_callout.dart",
    "lib/features/guided_journey/widgets/guided_journey_common_widgets.dart",
    "lib/features/guided_journey/widgets/guided_journey_overview.dart",
    "lib/features/guided_journey/widgets/guided_journey_overview_tiles.dart",
    "lib/features/guided_journey/widgets/guided_journey_resource_list.dart",
    "lib/features/guided_journey/widgets/guided_journey_stage_view.dart",
    "lib/pages/account/guided_journey_page.dart",
    "lib/pages/account/saved_journey_summary_page.dart",
    "test/guided_journey_page_test.dart",
    "test/guided_journey_visible_content_test.dart",
]


def git_show(path: str) -> str:
    return subprocess.check_output(["git", "show", f"{SOURCE}:{path}"], text=True)


def write_from_source(path: str) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(git_show(path), encoding="utf-8")


for file_path in COPY_FILES:
    write_from_source(file_path)

toolbox_path = Path("lib/pages/toolbox_je_me_lance_page.dart")
toolbox = toolbox_path.read_text(encoding="utf-8")
import_line = "import 'package:presto_app/pages/account/guided_journey_page.dart';\n"
anchor = "import 'package:presto_app/pages/account_page.dart';\n"
if import_line not in toolbox:
    toolbox = toolbox.replace(anchor, anchor + import_line, 1)

toolbox = toolbox.replace("builder: (_) => _JourneySummaryPage(", "builder: (_) => GuidedJourneyPage(")
toolbox = toolbox.replace("return _JourneySummaryPage(", "return GuidedJourneyPage(")
toolbox_path.write_text(toolbox, encoding="utf-8")

pdf_path = Path("lib/services/journey_pdf_export_service.dart")
pdf = pdf_path.read_text(encoding="utf-8")
progress_line = "    _appendMap(widgets, 'Progression guidée', journey['guidedProgress']);\n"
anchor_pdf = "    _appendTimeline(widgets, 'Étapes détaillées', journey['steps']);\n"
if progress_line not in pdf:
    pdf = pdf.replace(anchor_pdf, anchor_pdf + progress_line, 1)
pdf_path.write_text(pdf, encoding="utf-8")

Path("tools/recover_guided_journey.py").unlink(missing_ok=True)
Path(".github/workflows/recover-guided-journey.yml").unlink(missing_ok=True)
