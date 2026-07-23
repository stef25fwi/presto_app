from __future__ import annotations

import re
from pathlib import Path

TARGET = Path("lib/pages/admin_space_page.dart")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


def main() -> None:
    source = TARGET.read_text(encoding="utf-8")

    old_domain_layout = """                                     Column(
                                       children: [
                                         for (final domain
                                             in computed.domains) ...[
                                           _AdminMetricDomainCard(
                                             domain: domain.domain,
                                             highlights: domain.highlights,
                                             series: domain.series,
                                             trendLabel: domain.trendLabel,
                                             note: domain.note,
                                             onTap: () =>
                                                 _openDomainDetails(domain),
                                           ),
                                           if (domain != computed.domains.last)
                                             const SizedBox(height: 12),
                                         ],
                                       ],
                                     ),"""

    new_domain_layout = """                                     LayoutBuilder(
                                       builder: (context, constraints) {
                                         final crossAxisCount =
                                             constraints.maxWidth >= 1050
                                                 ? 3
                                                 : constraints.maxWidth >= 640
                                                     ? 2
                                                     : 1;
                                         return GridView.builder(
                                           itemCount: computed.domains.length,
                                           shrinkWrap: true,
                                           physics: const
                                               NeverScrollableScrollPhysics(),
                                           gridDelegate:
                                               SliverGridDelegateWithFixedCrossAxisCount(
                                             crossAxisCount: crossAxisCount,
                                             mainAxisSpacing: 12,
                                             crossAxisSpacing: 12,
                                             mainAxisExtent: 190,
                                           ),
                                           itemBuilder: (context, index) {
                                             final domain =
                                                 computed.domains[index];
                                             return _AdminMetricDomainCard(
                                               domain: domain.domain,
                                               highlights: domain.highlights,
                                               series: domain.series,
                                               trendLabel: domain.trendLabel,
                                               note: domain.note,
                                               onTap: () =>
                                                   _openDomainDetails(domain),
                                             );
                                           },
                                         );
                                       },
                                     ),"""

    source = replace_once(
        source,
        old_domain_layout,
        new_domain_layout,
        "dashboard domain layout",
    )

    card_pattern = re.compile(
        r"class _AdminMetricDomainCard extends StatelessWidget \{.*?\n\}\n\nclass _AdminMiniChart extends StatelessWidget \{",
        re.DOTALL,
    )

    new_card = """class _AdminMetricDomainCard extends StatelessWidget {
  final _AdminMetricDomain domain;
  final List<_AdminDashboardStat> highlights;
  final List<double> series;
  final String trendLabel;
  final String note;
  final VoidCallback? onTap;

  const _AdminMetricDomainCard({
    required this.domain,
    required this.highlights,
    required this.series,
    required this.trendLabel,
    required this.note,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final visibleHighlights = highlights.take(2).toList(growable: false);
    return Semantics(
      button: onTap != null,
      label: 'Ouvrir ${domain.title}',
      child: _CardShell(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: domain.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: domain.color.withValues(alpha: 0.20),
                        ),
                      ),
                      child: Icon(domain.icon, color: domain.color, size: 21),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        domain.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          height: 1.15,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: domain.color,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (visibleHighlights.isEmpty)
                  const Text(
                    'Données en cours de consolidation',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final stat in visibleHighlights)
                        _AdminDomainTileStat(
                          label: stat.label,
                          value: stat.value,
                          color: domain.color,
                        ),
                    ],
                  ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        trendLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Voir le détail',
                      style: TextStyle(
                        color: domain.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminDomainTileStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AdminDomainTileStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        '$label : $value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AdminMiniChart extends StatelessWidget {"""

    source, replacements = card_pattern.subn(new_card, source, count=1)
    if replacements != 1:
        raise SystemExit(
            f"admin domain card: expected exactly one replacement, found {replacements}"
        )

    TARGET.write_text(source, encoding="utf-8")


if __name__ == "__main__":
    main()
