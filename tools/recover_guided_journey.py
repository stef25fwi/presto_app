from pathlib import Path
import subprocess

# Triggered after the cleanup workflow exists on the branch.
# Restore the two large legacy files exactly from current main, then apply only
# the minimal integration edits required by the guided renderer.
subprocess.run(
    [
        "git",
        "checkout",
        "origin/main",
        "--",
        "lib/pages/toolbox_je_me_lance_page.dart",
        "lib/services/journey_pdf_export_service.dart",
    ],
    check=True,
)

toolbox_path = Path("lib/pages/toolbox_je_me_lance_page.dart")
toolbox = toolbox_path.read_text(encoding="utf-8")
import_line = "import 'package:presto_app/pages/account/guided_journey_page.dart';\n"
anchor = "import 'package:presto_app/pages/account_page.dart';\n"
if import_line not in toolbox:
    toolbox = toolbox.replace(anchor, anchor + import_line, 1)
toolbox = toolbox.replace(
    "builder: (_) => _JourneySummaryPage(",
    "builder: (_) => GuidedJourneyPage(",
)
toolbox = toolbox.replace(
    "return _JourneySummaryPage(",
    "return GuidedJourneyPage(",
)
toolbox_path.write_text(toolbox, encoding="utf-8")

pdf_path = Path("lib/services/journey_pdf_export_service.dart")
pdf = pdf_path.read_text(encoding="utf-8")
progress_line = "    _appendMap(widgets, 'Progression guidée', journey['guidedProgress']);\n"
anchor_pdf = "    _appendTimeline(widgets, 'Étapes détaillées', journey['steps']);\n"
if progress_line not in pdf:
    pdf = pdf.replace(anchor_pdf, anchor_pdf + progress_line, 1)
pdf_path.write_text(pdf, encoding="utf-8")

Path("tools/recover_guided_journey.py").unlink(missing_ok=True)
Path(".github/workflows/minimize-guided-journey-diff.yml").unlink(missing_ok=True)
