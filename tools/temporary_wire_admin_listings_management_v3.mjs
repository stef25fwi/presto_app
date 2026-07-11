import { readFile, writeFile } from 'node:fs/promises';

const path = 'lib/pages/admin_space_page.dart';
let source = await readFile(path, 'utf8');

const importLine =
  "import 'package:presto_app/admin/listings/admin_listings_management_page.dart';";
const importAnchor =
  "import 'package:presto_app/admin/messaging/admin_messaging_dashboard_page.dart';";
if (!source.includes(importLine)) {
  if (!source.includes(importAnchor)) {
    throw new Error('admin listings import anchor not found');
  }
  source = source.replace(importAnchor, `${importLine}\n${importAnchor}`);
}

const tileAnchor = `                  _KpiTile(
                    icon: Icons.campaign_rounded,
                    title: 'Offres',
                    subtitle: _kpiSnapshot == null
                        ? 'Chargement…'
                        : 'Actives: \${_formatCompactNumber(_kpiSnapshot!.activeListings)}\\nTotal: \${_formatCompactNumber(_kpiSnapshot!.publishedListings)}\\nExpirées: \${_formatCompactNumber(_kpiSnapshot!.expiredListings)}',
                    badge: null,
                    iconColor: prestoOrange,
                  ),`;
const wiredTile = `                  _KpiTile(
                    icon: Icons.campaign_rounded,
                    title: 'Offres',
                    subtitle: _kpiSnapshot == null
                        ? 'Chargement…'
                        : 'Actives: \${_formatCompactNumber(_kpiSnapshot!.activeListings)}\\nTotal: \${_formatCompactNumber(_kpiSnapshot!.publishedListings)}\\nExpirées: \${_formatCompactNumber(_kpiSnapshot!.expiredListings)}',
                    badge: null,
                    iconColor: prestoOrange,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminListingsManagementPage(),
                        ),
                      );
                    },
                  ),`;

if (!source.includes(wiredTile)) {
  if (!source.includes(tileAnchor)) {
    throw new Error('admin offers tile anchor not found');
  }
  source = source.replace(tileAnchor, wiredTile);
}

await writeFile(path, source, 'utf8');
console.log('admin listings management navigation wired');
