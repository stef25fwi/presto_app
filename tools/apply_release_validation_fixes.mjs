#!/usr/bin/env node

import fs from 'node:fs/promises';

async function read(path) {
  return fs.readFile(path, 'utf8');
}

async function write(path, content) {
  await fs.writeFile(path, content, 'utf8');
}

function replaceOnce(content, before, after, label) {
  if (content.includes(after)) return content;
  const count = content.split(before).length - 1;
  if (count !== 1) {
    throw new Error(`${label}: expected exactly one occurrence, found ${count}`);
  }
  return content.replace(before, after);
}

async function patchSubscriptionApi() {
  const path = 'lib/features/subscriptions/subscription_widgets.dart';
  let content = await read(path);
  if (content.includes('enum _OfferAudience')) {
    content = content.replaceAll('_OfferAudience', 'OfferAudience');
  } else if (!content.includes('enum OfferAudience')) {
    throw new Error('subscription audience enum not found');
  }
  await write(path, content);
}

async function patchAuthStaticTest() {
  const path = 'test/auth_email_static_test.dart';
  let content = await read(path);
  content = replaceOnce(
    content,
    "      expect(auth, contains('.delete()'));",
    "      expect(auth, contains(\"name: 'requestAccountDeletion'\"));\n      expect(auth, isNot(contains('await user.delete()')));",
    'account deletion static assertion',
  );
  await write(path, content);
}

async function patchUserAuthorityTest() {
  const path = 'functions/scripts/test_user_authority_rules.mjs';
  let content = await read(path);
  if (content.includes("      { accountStatus: 'active' },")) {
    content = content.replace(
      "      { accountStatus: 'active' },",
      "      { accountStatus: 'disabled' },",
    );
  } else if (!content.includes("      { accountStatus: 'disabled' },") &&
             !content.includes("      { accountStatus: 'suspended' },")) {
    throw new Error('protected account status test not found');
  }
  await write(path, content);
}

async function patchJourneyLayouts() {
  const path = 'lib/pages/toolbox_je_me_lance_page.dart';
  let content = await read(path);

  content = replaceOnce(
    content,
    '      child: SizedBox(\n        height: 94,',
    '      child: SizedBox(\n        height: 108,',
    'responsive journey header height',
  );

  content = replaceOnce(
    content,
    '                    Text(\n                      _currentStepTitle,\n                      textAlign: TextAlign.center,',
    '                    Text(\n                      _currentStepTitle,\n                      textAlign: TextAlign.center,\n                      maxLines: 2,\n                      overflow: TextOverflow.ellipsis,',
    'journey header title bounds',
  );

  const statusBefore = `                ..._starterStatuses.map(
                  (status) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(status),
                    trailing: _situation == status
                        ? const Icon(Icons.check_circle, color: kBlue)
                        : null,
                    onTap: () {
                      setState(() {
                        _situation = status;
                        _showStarterErrors = false;
                      });
                      Navigator.of(sheetContext).pop();
                      _onAnyFieldChanged();
                    },
                  ),
                ),`;
  const statusAfter = `                ..._starterStatuses.map(
                  (status) => Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(status),
                      trailing: _situation == status
                          ? const Icon(Icons.check_circle, color: kBlue)
                          : null,
                      onTap: () {
                        setState(() {
                          _situation = status;
                          _showStarterErrors = false;
                        });
                        Navigator.of(sheetContext).pop();
                        _onAnyFieldChanged();
                      },
                    ),
                  ),
                ),`;
  content = replaceOnce(
    content,
    statusBefore,
    statusAfter,
    'status picker Material tiles',
  );

  const activityBefore = `                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(activity),
                        trailing: _selectedActivity == activity
                            ? const Icon(Icons.check_circle, color: kBlue)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedActivity = activity;
                            _activityType =
                                _resolveActivityTypeFromSelection(activity);
                            _showStarterErrors = false;
                          });
                          Navigator.of(sheetContext).pop();
                          _onAnyFieldChanged();
                        },
                      );`;
  const activityAfter = `                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(activity),
                          trailing: _selectedActivity == activity
                              ? const Icon(Icons.check_circle, color: kBlue)
                              : null,
                          onTap: () {
                            setState(() {
                              _selectedActivity = activity;
                              _activityType =
                                  _resolveActivityTypeFromSelection(activity);
                              _showStarterErrors = false;
                            });
                            Navigator.of(sheetContext).pop();
                            _onAnyFieldChanged();
                          },
                        ),
                      );`;
  content = replaceOnce(
    content,
    activityBefore,
    activityAfter,
    'activity picker Material tiles',
  );

  const chipBefore = `            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1A73E8),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),`;
  const chipAfter = `            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
                style: const TextStyle(
                  color: Color(0xFF1A73E8),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),`;
  content = replaceOnce(
    content,
    chipBefore,
    chipAfter,
    'task contact chip wrapping',
  );

  await write(path, content);
}

await patchSubscriptionApi();
await patchAuthStaticTest();
await patchUserAuthorityTest();
await patchJourneyLayouts();

console.log('release validation fixes: OK');
