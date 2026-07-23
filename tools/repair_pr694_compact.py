# Déclencheur déterministe de compaction PR #694.
from pathlib import Path

TARGET = Path('lib/pages/messages/conversations_list_page.dart')
TEMP_EXECUTOR = Path('.github/workflows/temp-compact-696.yml')

OLD = '''    WidgetsBinding.instance.addPostFrameCallback((_) {
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

NEW = '''    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_diagPanelVisible) return;
      setState(() {
        final logs = _adminConversationLoadLogs;
        logs.insert(0, line);
        if (logs.length > 40) logs.removeRange(40, logs.length);
      });
    });'''

text = TARGET.read_text(encoding='utf-8')
if NEW not in text:
    if OLD not in text:
        raise SystemExit('Expected expanded post-frame block not found')
    TARGET.write_text(text.replace(OLD, NEW, 1), encoding='utf-8')

TEMP_EXECUTOR.unlink(missing_ok=True)
