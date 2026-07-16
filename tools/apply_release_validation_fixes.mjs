#!/usr/bin/env node

import fs from 'node:fs/promises';

async function read(path) {
  return fs.readFile(path, 'utf8');
}

async function write(path, content) {
  await fs.writeFile(path, content, 'utf8');
}

function replaceKnown(content, before, after) {
  if (content.includes(after)) return content;
  if (!content.includes(before)) return content;
  return content.replace(before, after);
}

async function patchSubscriptionApi() {
  const path = 'lib/features/subscriptions/subscription_widgets.dart';
  let content = await read(path);
  if (content.includes('enum _OfferAudience')) {
    content = content.replaceAll('_OfferAudience', 'OfferAudience');
  }
  await write(path, content);
}

async function patchAuthStaticTest() {
  const path = 'test/auth_email_static_test.dart';
  let content = await read(path);
  content = replaceKnown(
    content,
    "      expect(auth, contains('.delete()'));",
    "      expect(auth, contains(\"name: 'requestAccountDeletion'\"));\n      expect(auth, isNot(contains('await user.delete()')));",
  );
  await write(path, content);
}

async function patchUserAuthorityTest() {
  const path = 'functions/scripts/test_user_authority_rules.mjs';
  let content = await read(path);
  content = content.replace(
    "      { accountStatus: 'active' },",
    "      { accountStatus: 'disabled' },",
  );
  await write(path, content);
}

async function patchJourneyLayouts() {
  const path = 'lib/pages/toolbox_je_me_lance_page.dart';
  let content = await read(path);

  content = content
    .replace('      child: SizedBox(\n        height: 94,',
      '      child: SizedBox(\n        height: 108,')
    .replace('      child: SizedBox(\n        height: 106,',
      '      child: SizedBox(\n        height: 108,');

  content = replaceKnown(
    content,
    '                    Text(\n                      _currentStepTitle,\n                      textAlign: TextAlign.center,',
    '                    Text(\n                      _currentStepTitle,\n                      textAlign: TextAlign.center,\n                      maxLines: 2,\n                      overflow: TextOverflow.ellipsis,',
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
  content = replaceKnown(content, statusBefore, statusAfter);

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
  content = replaceKnown(content, activityBefore, activityAfter);

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
  content = replaceKnown(content, chipBefore, chipAfter);

  await write(path, content);
}

await patchSubscriptionApi();
await patchAuthStaticTest();
await patchUserAuthorityTest();
await patchJourneyLayouts();

console.log('release validation fixes: OK');
// Controlled trigger for the PR459 repair workflow.
