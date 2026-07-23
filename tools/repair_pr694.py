# Déclencheur déterministe de la réparation PR #694.
from pathlib import Path

TARGET = Path('lib/pages/messages/conversations_list_page.dart')
TEMP_EXECUTOR = Path('.github/workflows/temp-fix-696.yml')

OLD = '''    if (!_diagPanelVisible || !mounted) return;

    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    final stamp =
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.${three(now.millisecond)}';
    final line = '[$stamp] $message';

    final maxLines = _diagPanelVisible ? 40 : 12;
    setState(() {
      _adminConversationLoadLogs.insert(0, line);
      if (_adminConversationLoadLogs.length > maxLines) {
        _adminConversationLoadLogs.removeRange(
          maxLines,
          _adminConversationLoadLogs.length,
        );
      }
    });'''

NEW = '''    if (!_diagPanelVisible || !mounted) return;

    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    String three(int v) => v.toString().padLeft(3, '0');
    final stamp =
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.${three(now.millisecond)}';
    final line = '[$stamp] $message';

    WidgetsBinding.instance.addPostFrameCallback((_) {
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

text = TARGET.read_text(encoding='utf-8')
if NEW not in text:
    if OLD not in text:
        raise SystemExit('Expected _appendAdminConversationLog block not found')
    TARGET.write_text(text.replace(OLD, NEW, 1), encoding='utf-8')

TEMP_EXECUTOR.unlink(missing_ok=True)
