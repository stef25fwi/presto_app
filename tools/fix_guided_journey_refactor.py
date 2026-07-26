from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / 'lib/pages/account/guided_journey_page.dart'

content = TARGET.read_text(encoding='utf-8')
old = '_activeIndex = index.clamp(0, _stages.length - 1);'
new = '_activeIndex = index.clamp(0, _stages.length - 1).toInt();'
if old in content:
    TARGET.write_text(content.replace(old, new), encoding='utf-8')
elif new not in content:
    raise RuntimeError('Unable to normalize the active guided stage index')

Path(__file__).unlink()
