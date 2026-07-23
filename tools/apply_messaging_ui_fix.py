from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"{label} anchor not found")
    return text.replace(old, new, 1)


thread_path = Path("lib/pages/messages/conversation_thread_page.dart")
text = thread_path.read_text()

text = replace_once(
    text,
    """                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(""",
    """                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(""",
    "TextField borders",
)

text = replace_once(
    text,
    "return buildDeleteOverlay(_VoiceNotePlayer(source: attachment.url));",
    """return buildDeleteOverlay(
        _VoiceNotePlayer(
          source: attachment.url,
          fallbackDuration: voiceNoteDurationFromName(attachment.name),
        ),
      );""",
    "voice note attachment",
)

text = replace_once(
    text,
    """class _VoiceNotePlayer extends StatefulWidget {
  final String source;
  final bool isLocalFile;

  const _VoiceNotePlayer({required this.source, this.isLocalFile = false});""",
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
    "voice note widget",
)

text = replace_once(
    text,
    """    super.initState();
    _player = AudioPlayer();""",
    """    super.initState();
    _total = widget.fallbackDuration;
    _player = AudioPlayer();""",
    "voice note init",
)

text = replace_once(
    text,
    """    if (oldWidget.source != widget.source ||
        oldWidget.isLocalFile != widget.isLocalFile) {""",
    """    if (oldWidget.source != widget.source ||
        oldWidget.isLocalFile != widget.isLocalFile ||
        oldWidget.fallbackDuration != widget.fallbackDuration) {""",
    "voice note update",
)

text = replace_once(
    text,
    """      _position = Duration.zero;
      _total = Duration.zero;
      _isLoading = false;""",
    """      _position = Duration.zero;
      _total = widget.fallbackDuration;
      _isLoading = false;""",
    "voice note reset",
)

thread_path.write_text(text)

debug_path = Path("lib/widgets/admin_web_debug_panel.dart")
debug = debug_path.read_text()

debug = replace_once(
    debug,
    """            Positioned(
              right: isSmallScreen ? 8 : 12,
              bottom: isSmallScreen ? 8 : 12,
              left: isSmallScreen ? 8 : null,
              child: SafeArea(""",
    """            Positioned(
              right: isSmallScreen ? 8 : 12,
              top: isSmallScreen ? 8 : 12,
              child: SafeArea(""",
    "debug position",
)

debug = replace_once(
    debug,
    """                    children: [
                      if (_isExpanded)
                        _buildExpandedPanel(context, adminState, isSmallScreen),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF111827),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 10 : 14,
                            vertical: isSmallScreen ? 10 : 12,
                          ),
                        ),
                        icon: Icon(
                          _isExpanded
                              ? Icons.bug_report_outlined
                              : Icons.monitor_heart_outlined,
                          size: isSmallScreen ? 18 : 20,
                        ),
                        label: Text(
                          _isExpanded
                              ? 'Masquer debug admin'
                              : 'Debug admin web',
                          style: TextStyle(fontSize: isSmallScreen ? 11 : 13),
                        ),
                      ),
                    ],""",
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
    "debug button",
)

debug_path.write_text(debug)
