from pathlib import Path

path = Path('lib/features/subscriptions/subscription_credits_card.dart')
text = path.read_text(encoding='utf-8')
old = """          return const _CreditsShell(
            child: SizedBox(
              height: 86,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            ),
          );"""
new = """          return const _CreditsShell(
            child: SizedBox(
              height: 54,
              child: Center(
                child: Text(
                  'Chargement de vos crédits…',
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );"""
if new not in text:
    if old not in text:
        raise SystemExit('loading marker not found')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('static credits loading applied')
