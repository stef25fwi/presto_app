# Déclencheur déterministe final de la réparation PR #694.
from pathlib import Path

TARGET = Path('lib/pages/messages/conversations_list_page.dart')
TEMP_EXECUTORS = (
    Path('.github/workflows/temp-fix-696.yml'),
    Path('.github/workflows/temp-compact-696.yml'),
)

DIRECT = '''    final maxLines = _diagPanelVisible ? 40 : 12;
    setState(() {
      _adminConversationLoadLogs.insert(0, line);
      if (_adminConversationLoadLogs.length > maxLines) {
        _adminConversationLoadLogs.removeRange(
          maxLines,
          _adminConversationLoadLogs.length,
        );
      }
    });'''

EXPANDED = '''    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_diagPanelVisible) return;
      final maxLines = _diagPanelVisible ? 40 : 12;
      setState(() {
        _adminConversationLoadLogs.insert(0, line);
        if (_adminConversationLoadLogs.length > maxLines) {
          _adminConversationLoadLogs.removeRange(
            maxLines,
            _adminConversationLoadLogs.length,
          );
        }
      });
    });'''

COMPACT = '''    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_diagPanelVisible) return;
      setState(() {
        final logs = _adminConversationLoadLogs;
        logs.insert(0, line);
        if (logs.length > 40) logs.removeRange(40, logs.length);
      });
    });'''

text = TARGET.read_text(encoding='utf-8')
if COMPACT not in text:
    if EXPANDED in text:
        text = text.replace(EXPANDED, COMPACT, 1)
    elif DIRECT in text:
        text = text.replace(DIRECT, COMPACT, 1)
    else:
        raise SystemExit('Expected admin log mutation block not found')
    TARGET.write_text(text, encoding='utf-8')

for executor in TEMP_EXECUTORS:
    executor.unlink(missing_ok=True)
