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

function replaceAllAtLeast(content, before, after, minimum, label) {
  const count = content.split(before).length - 1;
  if (count === 0 && content.includes(after)) return content;
  if (count < minimum) {
    throw new Error(`${label}: expected at least ${minimum} occurrence(s), found ${count}`);
  }
  return content.replaceAll(before, after);
}

function transformRange(content, startMarker, endMarker, transform, label) {
  const start = content.indexOf(startMarker);
  const end = content.indexOf(endMarker, start + startMarker.length);
  if (start < 0 || end < 0 || end <= start) {
    throw new Error(`${label}: range markers not found`);
  }
  const range = content.slice(start, end);
  const nextRange = transform(range);
  return `${content.slice(0, start)}${nextRange}${content.slice(end)}`;
}

// ---------------------------------------------------------------------------
// Page Mon compte : bord d’écran, cartes principales et version entreprise.
// ---------------------------------------------------------------------------
const accountPath = 'lib/pages/account_page.dart';
let account = await read(accountPath);

account = replaceOnce(
  account,
  'padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),',
  'padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),',
  'profile completeness padding',
);

account = replaceOnce(
  account,
  `          width: 38,\n          height: 38,`,
  `          width: 34,\n          height: 34,`,
  'account section icon size',
);

account = replaceOnce(
  account,
  `        const SizedBox(width: 12),\n        Expanded(\n          child: Column(\n            crossAxisAlignment: CrossAxisAlignment.start,`,
  `        const SizedBox(width: 8),\n        Expanded(\n          child: Column(\n            crossAxisAlignment: CrossAxisAlignment.start,`,
  'account section icon gap',
);

account = replaceOnce(
  account,
  'padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),',
  'padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),',
  'account section card padding',
);

account = replaceOnce(
  account,
  `          if (alwaysVisibleChild != null) ...[\n            const SizedBox(height: 14),\n            alwaysVisibleChild,\n          ],\n          if (!isCollapsible || isExpanded) ...[\n            const SizedBox(height: 14),`,
  `          if (alwaysVisibleChild != null) ...[\n            const SizedBox(height: 10),\n            alwaysVisibleChild,\n          ],\n          if (!isCollapsible || isExpanded) ...[\n            const SizedBox(height: 10),`,
  'account section inner gaps',
);

account = replaceOnce(
  account,
  'padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),',
  'padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),',
  'account screen edge padding',
);

account = replaceOnce(
  account,
  'padding: const EdgeInsets.only(top: 16, bottom: 20),',
  'padding: const EdgeInsets.only(top: 10, bottom: 12),',
  'account logo spacing',
);

account = replaceOnce(
  account,
  `                              padding: const EdgeInsets.symmetric(\n                                horizontal: 14,\n                                vertical: 12,\n                              ),`,
  `                              padding: const EdgeInsets.symmetric(\n                                horizontal: 10,\n                                vertical: 9,\n                              ),`,
  'account alert intro padding',
);

account = transformRange(
  account,
  '        body: Center(\n          child: Padding(',
  '  Widget _buildAdminSpaceEntry(User user) {',
  (range) => range
    .replaceAll('const SizedBox(height: 24),', 'const SizedBox(height: 12),')
    .replaceAll('const SizedBox(height: 28),', 'const SizedBox(height: 14),'),
  'default account vertical spacing',
);

account = replaceOnce(
  account,
  'padding: const EdgeInsets.fromLTRB(16, 28, 16, 100),',
  'padding: const EdgeInsets.fromLTRB(6, 16, 6, 80),',
  'enterprise account edge padding',
);

account = transformRange(
  account,
  '  Widget _buildEnterpriseScaffold(',
  '  Widget _buildEnterpriseHeader(',
  (range) => range
    .replaceAll('const SizedBox(height: 28),', 'const SizedBox(height: 16),')
    .replaceAll('const SizedBox(height: 20),', 'const SizedBox(height: 12),'),
  'enterprise account vertical spacing',
);

account = replaceOnce(
  account,
  'padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),',
  'padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),',
  'enterprise confidence card padding',
);

account = transformRange(
  account,
  '  Widget _buildOrangeMenuItem({',
  '  Widget _buildEnterpriseMenuSection(User user) {',
  (range) => range
    .replaceAll(
      'padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),',
      'padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),',
    )
    .replaceAll('const SizedBox(width: 16),', 'const SizedBox(width: 10),'),
  'enterprise orange menu spacing',
);

account = transformRange(
  account,
  '  Widget _buildBlueMenuItem({',
  '  Widget _buildDefaultHeader(',
  (range) => range
    .replaceAll(
      'padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),',
      'padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),',
    )
    .replaceAll('const SizedBox(width: 16),', 'const SizedBox(width: 10),'),
  'enterprise blue menu spacing',
);

account = replaceAllAtLeast(
  account,
  `margin: const EdgeInsets.only(bottom: 18),\n              padding: const EdgeInsets.all(14),`,
  `margin: const EdgeInsets.only(bottom: 10),\n              padding: const EdgeInsets.all(10),`,
  1,
  'admin account card spacing',
);

await write(accountPath, account);

// ---------------------------------------------------------------------------
// Tuile Notifications.
// ---------------------------------------------------------------------------
const notificationsPath = 'lib/widgets/account_notifications_tile.dart';
let notifications = await read(notificationsPath);

notifications = replaceOnce(
  notifications,
  `    return Card(\n      elevation: 0,`,
  `    return Card(\n      margin: EdgeInsets.zero,\n      elevation: 0,`,
  'notifications card margin',
);
notifications = replaceOnce(
  notifications,
  'padding: const EdgeInsets.all(16),',
  'padding: const EdgeInsets.all(10),',
  'notifications inner padding',
);
notifications = replaceOnce(
  notifications,
  `                const SizedBox(width: 10),\n                const Expanded(`,
  `                const SizedBox(width: 8),\n                const Expanded(`,
  'notifications header gap',
);
notifications = replaceOnce(
  notifications,
  `            SwitchListTile(\n              contentPadding: EdgeInsets.zero,`,
  `            SwitchListTile(\n              contentPadding: EdgeInsets.zero,\n              dense: true,\n              visualDensity: VisualDensity.compact,`,
  'notifications compact switch',
);
notifications = replaceOnce(
  notifications,
  'padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),',
  'padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),',
  'notifications badge padding',
);

await write(notificationsPath, notifications);

// ---------------------------------------------------------------------------
// Sous-cartes Profil / Alertes / Messages.
// ---------------------------------------------------------------------------
const profileSectionsPath = 'lib/widgets/account_profile_sections.dart';
let profileSections = await read(profileSectionsPath);

profileSections = replaceOnce(
  profileSections,
  'const double _kAccountSectionTileHorizontalPadding = 10;',
  'const double _kAccountSectionTileHorizontalPadding = 8;',
  'account section tile horizontal padding',
);
profileSections = replaceAllAtLeast(
  profileSections,
  'vertical: 14,',
  'vertical: 11,',
  3,
  'account section tile vertical 14 padding',
);
profileSections = replaceAllAtLeast(
  profileSections,
  'vertical: 12,',
  'vertical: 10,',
  1,
  'account section tile vertical 12 padding',
);
profileSections = replaceOnce(
  profileSections,
  'vertical: 18,',
  'vertical: 12,',
  'pro upgrade compact padding',
);

await write(profileSectionsPath, profileSections);

// ---------------------------------------------------------------------------
// Carte d’abonnement visible dans Mon compte.
// ---------------------------------------------------------------------------
const subscriptionsPath = 'lib/features/subscriptions/subscription_widgets.dart';
let subscriptions = await read(subscriptionsPath);

subscriptions = transformRange(
  subscriptions,
  'class SubscriptionSection extends StatelessWidget {',
  'class SubscriptionDetailsPage extends StatefulWidget {',
  (range) => range
    .replace(
      'padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),',
      'padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),',
    )
    .replace('borderRadius: BorderRadius.circular(28),', 'borderRadius: BorderRadius.circular(20),')
    .replace('const SizedBox(height: 18),', 'const SizedBox(height: 10),')
    .replace('const SizedBox(height: 14),', 'const SizedBox(height: 10),'),
  'subscription overview compact spacing',
);

subscriptions = transformRange(
  subscriptions,
  'class SubscriptionCurrentStatusCard extends StatelessWidget {',
  'class SubscriptionPlanTabs extends StatelessWidget {',
  (range) => range
    .replace(
      'padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),',
      'padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),',
    )
    .replace('borderRadius: BorderRadius.circular(24),', 'borderRadius: BorderRadius.circular(18),')
    .replaceAll('const SizedBox(height: 16),', 'const SizedBox(height: 12),')
    .replaceAll('const SizedBox(height: 14),', 'const SizedBox(height: 10),')
    .replace('const SizedBox(width: 14),', 'const SizedBox(width: 10),')
    .replace('padding: const EdgeInsets.symmetric(vertical: 15),', 'padding: const EdgeInsets.symmetric(vertical: 12),'),
  'current subscription card compact spacing',
);

await write(subscriptionsPath, subscriptions);

console.log('account compact spacing: OK');
