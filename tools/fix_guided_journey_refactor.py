from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace(path: str, old: str, new: str) -> None:
    target = ROOT / path
    content = target.read_text(encoding='utf-8')
    if old not in content:
        raise RuntimeError(f'Pattern not found in {path}: {old}')
    target.write_text(content.replace(old, new), encoding='utf-8')


replace(
    'lib/pages/account/guided_journey_page.dart',
    '_activeIndex = index.clamp(0, _stages.length - 1);',
    '_activeIndex = index.clamp(0, _stages.length - 1).toInt();',
)
replace(
    'lib/features/guided_journey/widgets/guided_journey_overview.dart',
    'final safeIndex = nextStageIndex.clamp(0, stages.length - 1);',
    'final safeIndex = nextStageIndex.clamp(0, stages.length - 1).toInt();',
)
replace(
    'lib/features/guided_journey/widgets/guided_journey_common_widgets.dart',
    'value: progress.clamp(0, 1),',
    'value: progress.clamp(0.0, 1.0).toDouble(),',
)

Path(__file__).unlink()
