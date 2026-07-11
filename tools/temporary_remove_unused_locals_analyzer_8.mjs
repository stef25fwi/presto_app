import { readFile, writeFile } from 'node:fs/promises';

const edits = [
  {
    path: 'lib/dev/page_capture_catalog_page.dart',
    before: "    final route = '/page-catalog?page=${item.id}';\n",
    after: '',
  },
  {
    path: 'lib/pages/admin_space_page.dart',
    before: "    final proLogins = _toInt(userStats?['proLogins']);\n",
    after: '',
  },
  {
    path: 'lib/pages/messages/conversation_thread_page.dart',
    before: `    final compactOutlinedStyle = OutlinedButton.styleFrom(\n      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),\n      minimumSize: const Size(0, 44),\n      textStyle: const TextStyle(\n        fontSize: 13,\n        fontWeight: FontWeight.w600,\n      ),\n    );\n    final compactFilledStyle = FilledButton.styleFrom(\n      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),\n      minimumSize: const Size(0, 44),\n      textStyle: const TextStyle(\n        fontSize: 13,\n        fontWeight: FontWeight.w600,\n      ),\n      backgroundColor: kWhatsappGreen,\n    );\n\n`,
    after: '',
  },
  {
    path: 'lib/pages/messages/conversations_list_page.dart',
    before: '    var appCheckPrefixRetryCount = 0;\n',
    after: '',
  },
  {
    path: 'lib/pages/offers/offer_details_page.dart',
    before: '    const navy = Color(0xFF18233D);\n',
    after: '',
  },
  {
    path: 'lib/pages/offers/offer_details_page.dart',
    before: '    const muted = Color(0xFF6F7282);\n',
    after: '',
  },
  {
    path: 'lib/pages/offers/offer_details_page.dart',
    before: '    const orange = Color(0xFFFF7B12);\n',
    after: '',
  },
  {
    path: 'lib/pages/offers/offer_details_page.dart',
    before: '    const green = Color(0xFF45B36B);\n',
    after: '',
  },
  {
    path: 'lib/pages/toolbox_je_me_lance_page.dart',
    before: '    final width = MediaQuery.of(context).size.width;\n    final isCompact = width < 370;\n\n',
    after: '',
  },
  {
    path: 'lib/services/value_analysis_service.dart',
    before: '    final reproductionWeight = 0.35;\n',
    after: '',
  },
  {
    path: 'lib/widgets/ad_banner.dart',
    before: '      final ph = widget.placeholderHeight ?? (kIsWeb ? 90.0 : 60.0);\n',
    after: '',
  },
];

for (const edit of edits) {
  const source = await readFile(edit.path, 'utf8');
  if (!source.includes(edit.before)) {
    if (!edit.after || source.includes(edit.after)) continue;
    throw new Error(`unused local anchor not found in ${edit.path}`);
  }
  await writeFile(edit.path, source.replace(edit.before, edit.after), 'utf8');
}

console.log('removed 12 unused local variables');
