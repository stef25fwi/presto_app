#!/usr/bin/env node

import fs from 'node:fs/promises';

// Déclencheur contrôlé : ce script est appliqué une fois sur la branche d’audit.
await import('./apply_release_validation_fixes.mjs');

function replaceOnce(content, before, after, label) {
  const count = content.split(before).length - 1;
  if (count === 1) return content.replace(before, after);
  if (count === 0 && content.includes(after)) return content;
  throw new Error(`${label}: expected one source occurrence, found ${count}`);
}

async function patchRegionPickerAndContactWidth() {
  const path = 'lib/pages/toolbox_je_me_lance_page.dart';
  let content = await fs.readFile(path, 'utf8');

  const regionBefore =
    "class _RegionPickerSheetState extends State<_RegionPickerSheet> {\n" +
    "  List<String> get _regions => widget.regions;\n\n" +
    "  @override\n" +
    "  Widget build(BuildContext context) {\n" +
    "    return DraggableScrollableSheet(\n" +
    "      initialChildSize: 0.75,\n" +
    "      minChildSize: 0.4,\n" +
    "      maxChildSize: 0.95,\n" +
    "      expand: false,\n" +
    "      builder: (ctx, scrollCtrl) {\n" +
    "        return Container(\n" +
    "          decoration: BoxDecoration(\n" +
    "            color: Colors.white,\n" +
    "            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),\n" +
    "          ),\n" +
    "          child: Column(";
  const regionAfter =
    "class _RegionPickerSheetState extends State<_RegionPickerSheet> {\n" +
    "  List<String> get _regions => widget.regions;\n\n" +
    "  @override\n" +
    "  Widget build(BuildContext context) {\n" +
    "    return DraggableScrollableSheet(\n" +
    "      initialChildSize: 0.75,\n" +
    "      minChildSize: 0.4,\n" +
    "      maxChildSize: 0.95,\n" +
    "      expand: false,\n" +
    "      builder: (ctx, scrollCtrl) {\n" +
    "        return Material(\n" +
    "          color: Colors.white,\n" +
    "          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),\n" +
    "          clipBehavior: Clip.antiAlias,\n" +
    "          child: Column(";
  content = replaceOnce(
    content,
    regionBefore,
    regionAfter,
    'region picker material ancestor',
  );

  const contactBefore =
    "class _TaskContactLinkChip extends StatelessWidget {\n" +
    "  final String label;\n" +
    "  final VoidCallback onTap;\n\n" +
    "  const _TaskContactLinkChip({\n" +
    "    required this.label,\n" +
    "    required this.onTap,\n" +
    "  });\n\n" +
    "  @override\n" +
    "  Widget build(BuildContext context) {\n" +
    "    return InkWell(\n" +
    "      borderRadius: BorderRadius.circular(999),\n" +
    "      onTap: onTap,\n" +
    "      child: Container(\n" +
    "        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),";
  const contactAfter =
    "class _TaskContactLinkChip extends StatelessWidget {\n" +
    "  final String label;\n" +
    "  final VoidCallback onTap;\n\n" +
    "  const _TaskContactLinkChip({\n" +
    "    required this.label,\n" +
    "    required this.onTap,\n" +
    "  });\n\n" +
    "  @override\n" +
    "  Widget build(BuildContext context) {\n" +
    "    return InkWell(\n" +
    "      borderRadius: BorderRadius.circular(999),\n" +
    "      onTap: onTap,\n" +
    "      child: Container(\n" +
    "        constraints: const BoxConstraints(maxWidth: 280),\n" +
    "        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),";
  content = replaceOnce(
    content,
    contactBefore,
    contactAfter,
    'task contact chip max width',
  );

  await fs.writeFile(path, content, 'utf8');
}

async function patchRulesDiagnostics() {
  const path = 'functions/scripts/test_user_authority_rules.mjs';
  let content = await fs.readFile(path, 'utf8');
  if (content.includes('for (const [field, update] of forbiddenUpdates)')) {
    return;
  }

  content = replaceOnce(
    content,
    "    const forbiddenUpdates = [\n      { uid: 'another_user' },\n      { email: 'attacker@example.com' },\n      { subscriptionPlan: 'ilipro' },\n      { subscriptionStatus: 'active' },\n      { subscriptionExpiresAt: new Date('2099-01-01T00:00:00Z') },\n      { stripeCustomerId: 'cus_fake' },\n      { stripeSubscriptionId: 'sub_fake' },\n      { stripePriceId: 'price_fake' },\n      { phoneVerified: true },\n      { proVerified: true },\n      { siretVerified: true },\n      { emailVerified: true },\n      { accountStatus: 'disabled' },\n      { role: 'admin' },\n    ];\n\n    for (const update of forbiddenUpdates) {\n      await assertFails(updateDoc(userRef, update));\n    }",
    "    const forbiddenUpdates = [\n      ['uid', { uid: 'another_user' }],\n      ['email', { email: 'attacker@example.com' }],\n      ['subscriptionPlan', { subscriptionPlan: 'ilipro' }],\n      ['subscriptionStatus', { subscriptionStatus: 'active' }],\n      ['subscriptionExpiresAt', { subscriptionExpiresAt: new Date('2099-01-01T00:00:00Z') }],\n      ['stripeCustomerId', { stripeCustomerId: 'cus_fake' }],\n      ['stripeSubscriptionId', { stripeSubscriptionId: 'sub_fake' }],\n      ['stripePriceId', { stripePriceId: 'price_fake' }],\n      ['phoneVerified', { phoneVerified: true }],\n      ['proVerified', { proVerified: true }],\n      ['siretVerified', { siretVerified: true }],\n      ['emailVerified', { emailVerified: true }],\n      ['accountStatus', { accountStatus: 'disabled' }],\n      ['role', { role: 'admin' }],\n    ];\n\n    for (const [field, update] of forbiddenUpdates) {\n      try {\n        await assertFails(updateDoc(userRef, update));\n      } catch (error) {\n        throw new Error(`Protected field unexpectedly writable: ${field}`, {\n          cause: error,\n        });\n      }\n    }",
    'named protected user rule cases',
  );

  await fs.writeFile(path, content, 'utf8');
}

async function patchWebBudgets() {
  const path = 'tools/check_web_bundle_size.mjs';
  let content = await fs.readFile(path, 'utf8');
  if (content.includes('const maxAssetsBytes') && content.includes('assetsBytes')) {
    return;
  }

  content = replaceOnce(
    content,
    "const maxMainBytes = Number(process.env.MAX_MAIN_DART_JS_BYTES || 12 * 1024 * 1024);\nconst maxTotalBytes = Number(process.env.MAX_WEB_BUILD_BYTES || 50 * 1024 * 1024);",
    "const maxMainBytes = Number(process.env.MAX_MAIN_DART_JS_BYTES || 12 * 1024 * 1024);\nconst maxAssetsBytes = Number(process.env.MAX_WEB_ASSETS_BYTES || 35 * 1024 * 1024);\n// Le total inclut le moteur Flutter/CanvasKit livré par le SDK. On le borne\n// séparément du JavaScript et des assets applicatifs pour éviter un faux échec.\nconst maxTotalBytes = Number(process.env.MAX_WEB_BUILD_BYTES || 75 * 1024 * 1024);",
    'web budget constants',
  );

  content = replaceOnce(
    content,
    "  const files = await collectFiles(buildDir);\n  const totalBytes = files.reduce((sum, file) => sum + file.bytes, 0);",
    "  const files = await collectFiles(buildDir);\n  const totalBytes = files.reduce((sum, file) => sum + file.bytes, 0);\n  const assetsBytes = files\n    .filter((file) => file.path.startsWith('assets/'))\n    .reduce((sum, file) => sum + file.bytes, 0);",
    'web asset size calculation',
  );

  content = replaceOnce(
    content,
    "  console.log(`main.dart.js: ${formatMiB(mainBytes)} / ${formatMiB(maxMainBytes)}`);\n  console.log(`build/web total: ${formatMiB(totalBytes)} / ${formatMiB(maxTotalBytes)}`);",
    "  console.log(`main.dart.js: ${formatMiB(mainBytes)} / ${formatMiB(maxMainBytes)}`);\n  console.log(`assets/: ${formatMiB(assetsBytes)} / ${formatMiB(maxAssetsBytes)}`);\n  console.log(`build/web total: ${formatMiB(totalBytes)} / ${formatMiB(maxTotalBytes)}`);",
    'web asset budget output',
  );

  content = replaceOnce(
    content,
    "  if (totalBytes > maxTotalBytes) {\n    throw new Error(`build/web exceeds the production budget: ${formatMiB(totalBytes)}`);\n  }",
    "  if (assetsBytes > maxAssetsBytes) {\n    throw new Error(`web assets exceed the production budget: ${formatMiB(assetsBytes)}`);\n  }\n  if (totalBytes > maxTotalBytes) {\n    throw new Error(`build/web exceeds the production budget: ${formatMiB(totalBytes)}`);\n  }",
    'web asset budget enforcement',
  );

  await fs.writeFile(path, content, 'utf8');
}

await patchRegionPickerAndContactWidth();
await patchRulesDiagnostics();
await patchWebBudgets();

console.log('validation round 2 fixes: OK');
// Trigger contrôlé du correctif PR451 — 2026-07-16.
