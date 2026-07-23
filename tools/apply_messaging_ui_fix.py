from pathlib import Path


def replace_required(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"{label} anchor not found")
    return text.replace(old, new, 1)


thread_path = Path("lib/pages/messages/conversation_thread_page.dart")
text = thread_path.read_text()

text = replace_required(
    text,
    """      return buildDeleteOverlay(
        _VoiceNotePlayer(
          source: attachment.url,
          fallbackDuration: voiceNoteDurationFromName(attachment.name),
        ),
      );""",
    "      return buildDeleteOverlay(_VoiceNotePlayer(source: attachment.url, fallbackDuration: voiceNoteDurationFromName(attachment.name)));",
    "compact voice note attachment",
)

text = replace_required(
    text,
    """                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(""",
    """                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, disabledBorder: InputBorder.none, errorBorder: InputBorder.none, focusedErrorBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(""",
    "compact TextField borders",
)

text = replace_required(
    text,
    """Duration voiceNoteDurationFromName(String name) {
  final match = RegExp(r'_(\\d+)s(?:\\.|$)').firstMatch(name.trim());
  final seconds = match == null ? null : int.tryParse(match.group(1) ?? '');
  return seconds == null || seconds <= 0
      ? Duration.zero
      : Duration(seconds: seconds);
}

class _VoiceNotePlayer extends StatefulWidget {
  final String source;
  final bool isLocalFile;
  final Duration fallbackDuration;

  const _VoiceNotePlayer({
    required this.source,
    this.isLocalFile = false,
    this.fallbackDuration = Duration.zero,
  });""",
    """Duration voiceNoteDurationFromName(String name) {
  final match = RegExp(r'_(\\d+)s(?:\\.|$)').firstMatch(name.trim());
  return Duration(seconds: int.tryParse(match?.group(1) ?? '') ?? 0);
}
class _VoiceNotePlayer extends StatefulWidget {
  final String source;
  final bool isLocalFile;
  final Duration fallbackDuration;
  const _VoiceNotePlayer({required this.source, this.isLocalFile = false, this.fallbackDuration = Duration.zero});""",
    "compact voice note widget",
)

text = replace_required(
    text,
    """    if (oldWidget.source != widget.source ||
        oldWidget.isLocalFile != widget.isLocalFile ||
        oldWidget.fallbackDuration != widget.fallbackDuration) {""",
    "    if (oldWidget.source != widget.source || oldWidget.isLocalFile != widget.isLocalFile || oldWidget.fallbackDuration != widget.fallbackDuration) {",
    "compact voice note update",
)

thread_path.write_text(text)

debug_path = Path("lib/widgets/admin_web_debug_panel.dart")
debug = debug_path.read_text()

debug = replace_required(
    debug,
    """                    children: [
                      if (isSmallScreen)
                        IconButton.filled(
                          tooltip: _isExpanded
                              ? 'Masquer le diagnostic admin'
                              : 'Ouvrir le diagnostic admin',
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF111827),
                            foregroundColor: Colors.white,
                          ),
                          icon: Icon(
                            _isExpanded
                                ? Icons.close_rounded
                                : Icons.monitor_heart_outlined,
                            size: 20,
                          ),
                        )
                      else
                        FilledButton.icon(
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF111827),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          icon: Icon(
                            _isExpanded
                                ? Icons.bug_report_outlined
                                : Icons.monitor_heart_outlined,
                            size: 20,
                          ),
                          label: Text(
                            _isExpanded
                                ? 'Masquer debug admin'
                                : 'Debug admin web',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      if (_isExpanded) ...[
                        const SizedBox(height: 8),
                        _buildExpandedPanel(context, adminState, isSmallScreen),
                      ],
                    ],""",
    """                    children: [
                      IconButton.filled(
                        tooltip: _isExpanded ? 'Masquer le diagnostic admin' : 'Ouvrir le diagnostic admin',
                        onPressed: () => setState(() => _isExpanded = !_isExpanded),
                        style: IconButton.styleFrom(backgroundColor: const Color(0xFF111827), foregroundColor: Colors.white),
                        icon: Icon(_isExpanded ? Icons.close_rounded : Icons.monitor_heart_outlined, size: 20),
                      ),
                      if (_isExpanded) ...[
                        const SizedBox(height: 8),
                        _buildExpandedPanel(context, adminState, isSmallScreen),
                      ],
                    ],""",
    "compact debug button",
)

debug_path.write_text(debug)
