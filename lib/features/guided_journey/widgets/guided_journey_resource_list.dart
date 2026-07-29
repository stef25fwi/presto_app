import 'package:flutter/material.dart';
import 'package:presto_app/features/guided_journey/guided_journey_models.dart';

import 'guided_journey_common_widgets.dart';

class GuidedJourneyResourceList extends StatefulWidget {
  final List<JourneyResourceLink> resources;
  final ValueChanged<String> onOpen;
  final int initiallyVisible;

  const GuidedJourneyResourceList({
    super.key,
    required this.resources,
    required this.onOpen,
    this.initiallyVisible = 2,
  });

  @override
  State<GuidedJourneyResourceList> createState() =>
      _GuidedJourneyResourceListState();
}

class _GuidedJourneyResourceListState extends State<GuidedJourneyResourceList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.resources.isEmpty) {
      return const Text(
        'Aucun lien complémentaire n’est nécessaire pour cette étape.',
        style: TextStyle(color: kGuidedJourneyMuted, height: 1.4),
      );
    }
    final visible = _expanded
        ? widget.resources
        : widget.resources.take(widget.initiallyVisible).toList();
    final hiddenCount = widget.resources.length - widget.initiallyVisible;
    final grouped = <String, List<JourneyResourceLink>>{};
    for (final resource in visible) {
      grouped.putIfAbsent(resource.category, () => []).add(resource);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in grouped.entries) ...[
          if (grouped.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                entry.key,
                style: const TextStyle(
                  color: kGuidedJourneyMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ...entry.value.map(
            (resource) => _GuidedJourneyResourceTile(
              resource: resource,
              onTap: () => widget.onOpen(resource.url),
            ),
          ),
        ],
        if (hiddenCount > 0) ...[
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
            ),
            label: Text(
              _expanded
                  ? 'Réduire la liste'
                  : 'Afficher les $hiddenCount autres ressources',
            ),
          ),
        ],
      ],
    );
  }
}

class _GuidedJourneyResourceTile extends StatelessWidget {
  final JourneyResourceLink resource;
  final VoidCallback onTap;

  const _GuidedJourneyResourceTile({
    required this.resource,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.open_in_new_rounded,
                    color: kGuidedJourneyBlue,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              resource.label,
                              style: const TextStyle(
                                color: kGuidedJourneyBlue,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (resource.isOfficial)
                            const Tooltip(
                              message: 'Source officielle',
                              child: Icon(
                                Icons.verified_outlined,
                                color: Color(0xFF0F766E),
                                size: 18,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        resource.description,
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      if (resource.region.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          resource.region,
                          style: const TextStyle(
                            color: kGuidedJourneyMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
