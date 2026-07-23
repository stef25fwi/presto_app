from pathlib import Path

path = Path("lib/pages/messages/conversation_thread_page.dart")
text = path.read_text()

old = """    _durationSub = _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _total = d);
    });"""
new = """    _durationSub = _player.onDurationChanged.listen((d) {
      if (!mounted || d <= Duration.zero) return;
      setState(() => _total = d);
    });"""

if new not in text:
    if old not in text:
        raise SystemExit("audio duration listener anchor not found")
    text = text.replace(old, new, 1)

path.write_text(text)
print("Audio duration stability correction applied.")
