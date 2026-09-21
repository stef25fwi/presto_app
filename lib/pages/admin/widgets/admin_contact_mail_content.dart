bool _isBrevoTrackingUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  final host = uri?.host.toLowerCase() ?? '';
  if (host.isEmpty) return false;
  return RegExp(
    r'(^|\.)[a-z0-9-]*sendibt\d*\.com$|(^|\.)r\.sendinblue\.com$|(^|\.)r\.brevo\.com$',
    caseSensitive: false,
  ).hasMatch(host);
}

bool _trackingLikeLabel(String value) => RegExp(
      r'sendibt\d*\.com|r\.sendinblue\.com|r\.brevo\.com',
      caseSensitive: false,
    ).hasMatch(value);

String _decodeEntities(String input) {
  var value = input
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
  value = value.replaceAllMapped(
    RegExp(r'&#(\d+);'),
    (match) {
      final code = int.tryParse(match.group(1) ?? '');
      return code == null || code <= 0 || code > 0x10ffff
          ? match.group(0)!
          : String.fromCharCode(code);
    },
  );
  value = value.replaceAllMapped(
    RegExp(r'&#x([0-9a-f]+);', caseSensitive: false),
    (match) {
      final code = int.tryParse(match.group(1) ?? '', radix: 16);
      return code == null || code <= 0 || code > 0x10ffff
          ? match.group(0)!
          : String.fromCharCode(code);
    },
  );
  return value;
}

String _normalizeLines(String input) {
  final lines = input
      .replaceAll(RegExp(r'\r\n?'), '\n')
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[\t ]+'), ' ').trimRight())
      .toList(growable: false);
  return lines
      .join('\n')
      .replaceAll(RegExp(r'\n[ \t]+'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String sanitizeAdminContactMailText(String input) {
  if (input.isEmpty) return '';

  var value = input.replaceAll('\u0000', '');

  value = value.replaceAllMapped(
    RegExp(
      r'!?\[([^\]]*)\]\((https?:\/\/[^)\s]+)\)',
      caseSensitive: false,
    ),
    (match) {
      final label = (match.group(1) ?? '').trim();
      final url = match.group(2) ?? '';
      if (_isBrevoTrackingUrl(url) &&
          (label.isEmpty || _trackingLikeLabel(label))) {
        return '';
      }
      return label;
    },
  );

  value = value.replaceAllMapped(
    RegExp(r'<(https?:\/\/[^>]+)>', caseSensitive: false),
    (match) {
      final url = match.group(1) ?? '';
      return _isBrevoTrackingUrl(url) ? '' : url;
    },
  );

  value = value.replaceAllMapped(
    RegExp(r'https?:\/\/[^\s<>\])}]+', caseSensitive: false),
    (match) {
      final url = match.group(0) ?? '';
      return _isBrevoTrackingUrl(url) ? '' : url;
    },
  );

  value = value
      .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s+', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*>\s?', multiLine: true), '')
      .replaceAllMapped(
        RegExp(r'^\s*[-*+]\s+', multiLine: true),
        (_) => '• ',
      )
      .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
      .replaceAll(RegExp(r'__([^_]+)__'), r'$1')
      .replaceAll(RegExp(r'~~([^~]+)~~'), r'$1')
      .replaceAll(RegExp(r'<[^>]+>'), '');

  return _normalizeLines(_decodeEntities(value));
}

String sanitizeAdminContactMailPreview(String input, {int maxLength = 280}) {
  final clean = sanitizeAdminContactMailText(input)
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (clean.length <= maxLength) return clean;
  return clean.substring(0, maxLength);
}
