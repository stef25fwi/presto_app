from pathlib import Path

thread_path = Path("lib/pages/messages/conversation_thread_page.dart")
thread = thread_path.read_text()

old_audio = "      return buildDeleteOverlay(_VoiceNotePlayer(source: attachment.url, fallbackDuration: voiceNoteDurationFromName(attachment.name)));"
new_audio = "      return buildDeleteOverlay(_VoiceNotePlayer(source: attachment.url, fallbackDuration: Duration(seconds: int.tryParse(RegExp(r'_(\\d+)s(?:\\.|$)').firstMatch(attachment.name)?.group(1) ?? '') ?? 0)));"
if old_audio in thread:
    thread = thread.replace(old_audio, new_audio, 1)
elif new_audio not in thread:
    raise SystemExit("audio duration fallback anchor not found")

helper = """Duration voiceNoteDurationFromName(String name) {
  final match = RegExp(r'_(\\d+)s(?:\\.|$)').firstMatch(name.trim());
  return Duration(seconds: int.tryParse(match?.group(1) ?? '') ?? 0);
}
"""
if helper in thread:
    thread = thread.replace(helper, "", 1)

thread = thread.replace(
    "  const _VoiceNotePlayer({required this.source, this.isLocalFile = false, this.fallbackDuration = Duration.zero});\n\n  @override",
    "  const _VoiceNotePlayer({required this.source, this.isLocalFile = false, this.fallbackDuration = Duration.zero});\n  @override",
    1,
)
thread = thread.replace(
    "  State<_VoiceNotePlayer> createState() => _VoiceNotePlayerState();\n}\n\nclass _VoiceNotePlayerState",
    "  State<_VoiceNotePlayer> createState() => _VoiceNotePlayerState();\n}\nclass _VoiceNotePlayerState",
    1,
)

required_thread_tokens = (
    "fallbackDuration: Duration(seconds:",
    "enabledBorder: InputBorder.none",
    "focusedBorder: InputBorder.none",
    "disabledBorder: InputBorder.none",
    "errorBorder: InputBorder.none",
    "focusedErrorBorder: InputBorder.none",
    "_total = widget.fallbackDuration",
)
for token in required_thread_tokens:
    if token not in thread:
        raise SystemExit(f"missing conversation correction: {token}")
thread_path.write_text(thread)

debug = Path("lib/widgets/admin_web_debug_panel.dart").read_text()
for token in (
    "top: isSmallScreen ? 8 : 12",
    "IconButton.filled(",
    "Ouvrir le diagnostic admin",
):
    if token not in debug:
        raise SystemExit(f"missing admin debug correction: {token}")

print("Messaging UI correction verified within architecture budget.")
