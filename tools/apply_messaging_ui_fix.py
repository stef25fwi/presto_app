from pathlib import Path

thread = Path("lib/pages/messages/conversation_thread_page.dart").read_text()
debug = Path("lib/widgets/admin_web_debug_panel.dart").read_text()

required_thread_tokens = (
    "fallbackDuration: voiceNoteDurationFromName(attachment.name)",
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

required_debug_tokens = (
    "top: isSmallScreen ? 8 : 12",
    "IconButton.filled(",
    "Ouvrir le diagnostic admin",
)
for token in required_debug_tokens:
    if token not in debug:
        raise SystemExit(f"missing admin debug correction: {token}")

print("Messaging UI correction verified.")
