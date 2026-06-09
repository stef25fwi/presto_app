import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/business_project_template.dart';
import '../models/local_organization.dart';
import '../models/public_aid.dart';
import '../services/local_business_guidance_repository.dart';

class BusinessGuidancePage extends StatefulWidget {
  const BusinessGuidancePage({super.key});

  static const routeName = '/business-guidance';

  @override
  State<BusinessGuidancePage> createState() => _BusinessGuidancePageState();
}

class _BusinessGuidancePageState extends State<BusinessGuidancePage> {
  final LocalBusinessGuidanceRepository _repository =
      const LocalBusinessGuidanceRepository();

  late Future<_BusinessGuidanceData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_BusinessGuidanceData> _loadData() async {
    final profile = await _loadCurrentUserProfile();

    final resolvedRegionCode = await _repository.resolveRegionCode(
      region:
          profile.regionCode.isNotEmpty ? profile.regionCode : profile.region,
      departmentCode: profile.departmentCode.isNotEmpty
          ? profile.departmentCode
          : profile.department,
    );

    final regionCode =
        resolvedRegionCode.isNotEmpty ? resolvedRegionCode : 'guadeloupe';

    final region = await _repository.getRegionByCode(regionCode);
    final organizations =
        await _repository.getOrganizationsForRegion(regionCode);
    final publicAids = await _repository.getPublicAidsForRegion(regionCode);
    final templates = await _repository.getProjectTemplates();

    return _BusinessGuidanceData(
      regionCode: regionCode,
      regionName: region?.name ?? profile.region.ifEmpty('Guadeloupe'),
      city: profile.city,
      department: profile.department,
      organizations: organizations,
      publicAids: publicAids,
      templates: templates,
      usedFallback: resolvedRegionCode.isEmpty,
    );
  }

  Future<_UserBusinessProfile> _loadCurrentUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const _UserBusinessProfile(
        region: 'Guadeloupe',
        regionCode: 'guadeloupe',
        department: '971',
        departmentCode: '971',
        city: '',
      );
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snapshot.data();

      if (data == null) {
        return const _UserBusinessProfile(
          region: 'Guadeloupe',
          regionCode: 'guadeloupe',
          department: '971',
          departmentCode: '971',
          city: '',
        );
      }

      return _UserBusinessProfile(
        region: data['region']?.toString() ?? '',
        regionCode: data['regionCode']?.toString() ?? '',
        department: data['department']?.toString() ?? '',
        departmentCode: data['departmentCode']?.toString() ?? '',
        city: data['city']?.toString() ?? '',
      );
    } catch (_) {
      return const _UserBusinessProfile(
        region: 'Guadeloupe',
        regionCode: 'guadeloupe',
        department: '971',
        departmentCode: '971',
        city: '',
      );
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadData();
    });

    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer mon activité'),
      ),
      body: FutureBuilder<_BusinessGuidanceData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: 'Impossible de charger les données régionales.',
              onRetry: _refresh,
            );
          }

          final data = snapshot.data;

          if (data == null) {
            return _ErrorState(
              message: 'Aucune donnée disponible.',
              onRetry: _refresh,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeaderCard(data: data),
                const SizedBox(height: 14),
                _WarningCard(usedFallback: data.usedFallback),
                const SizedBox(height: 14),
                _ProjectTemplatesSection(templates: data.templates),
                const SizedBox(height: 14),
                _OrganizationsSection(organizations: data.organizations),
                const SizedBox(height: 14),
                _PublicAidsSection(publicAids: data.publicAids),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.data});

  final _BusinessGuidanceData data;

  @override
  Widget build(BuildContext context) {
    final locationParts = <String>[
      if (data.city.trim().isNotEmpty) data.city,
      if (data.department.trim().isNotEmpty) data.department,
      data.regionName,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parcours localisé',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              locationParts.join(' • '),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Code région : ${data.regionCode}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            const Text(
              'L’application affiche les organismes, aides et fiches projet selon la région du profil utilisateur.',
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.usedFallback});

  final bool usedFallback;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(
          usedFallback ? Icons.info_outline : Icons.verified_outlined,
        ),
        title: Text(
          usedFallback
              ? 'Région du profil non détectée'
              : 'Données régionales chargées',
        ),
        subtitle: Text(
          usedFallback
              ? 'La Guadeloupe est utilisée par défaut. Complète la région, le département et la ville dans le profil utilisateur.'
              : 'Les informations affichées correspondent à la région détectée dans le profil.',
        ),
      ),
    );
  }
}

class _ProjectTemplatesSection extends StatelessWidget {
  const _ProjectTemplatesSection({required this.templates});

  final List<BusinessProjectTemplate> templates;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Fiches projet disponibles',
      icon: Icons.description_outlined,
      emptyMessage: 'Aucune fiche projet disponible pour le moment.',
      children: [
        for (final template in templates)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            leading: const Icon(Icons.assignment_outlined),
            title: Text(template.title),
            subtitle: Text(template.category),
            childrenPadding:
                const EdgeInsets.only(left: 16, right: 8, bottom: 12),
            children: [
              _TextListBlock(
                title: 'Étapes principales',
                items: template.defaultSteps,
              ),
              const SizedBox(height: 8),
              _TextListBlock(
                title: 'Documents à préparer',
                items: template.requiredDocuments,
              ),
            ],
          ),
      ],
    );
  }
}

class _OrganizationsSection extends StatelessWidget {
  const _OrganizationsSection({required this.organizations});

  final List<LocalOrganization> organizations;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Organismes locaux',
      icon: Icons.account_balance_outlined,
      emptyMessage: 'Aucun organisme local disponible pour cette région.',
      children: [
        for (final org in organizations)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_iconForOrganization(org.type)),
            title: Text(org.name),
            subtitle: Text(org.description),
            trailing: _StatusBadge(enabled: org.enabled),
          ),
      ],
    );
  }

  IconData _iconForOrganization(String type) {
    switch (type) {
      case 'cci':
        return Icons.storefront_outlined;
      case 'cma':
        return Icons.handyman_outlined;
      case 'region':
        return Icons.account_balance_outlined;
      case 'france_travail':
        return Icons.work_outline;
      case 'france_services':
        return Icons.support_agent_outlined;
      default:
        return Icons.business_outlined;
    }
  }
}

class _PublicAidsSection extends StatelessWidget {
  const _PublicAidsSection({required this.publicAids});

  final List<PublicAid> publicAids;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Aides publiques et accompagnements',
      icon: Icons.volunteer_activism_outlined,
      emptyMessage: 'Aucune aide publique disponible pour cette région.',
      children: [
        for (final aid in publicAids)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            leading: const Icon(Icons.volunteer_activism_outlined),
            title: Text(aid.title),
            subtitle: Text(aid.provider),
            childrenPadding:
                const EdgeInsets.only(left: 16, right: 8, bottom: 12),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(aid.description),
              ),
              const SizedBox(height: 8),
              _TextListBlock(
                title: 'Éligibilité indicative',
                items: aid.eligibility,
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'À vérifier auprès de l’organisme officiel avant toute démarche.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    required this.emptyMessage,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (children.isEmpty) Text(emptyMessage) else ...children,
          ],
        ),
      ),
    );
  }
}

class _TextListBlock extends StatelessWidget {
  const _TextListBlock({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• '),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(enabled ? 'Actif' : 'Inactif'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessGuidanceData {
  const _BusinessGuidanceData({
    required this.regionCode,
    required this.regionName,
    required this.city,
    required this.department,
    required this.organizations,
    required this.publicAids,
    required this.templates,
    required this.usedFallback,
  });

  final String regionCode;
  final String regionName;
  final String city;
  final String department;
  final List<LocalOrganization> organizations;
  final List<PublicAid> publicAids;
  final List<BusinessProjectTemplate> templates;
  final bool usedFallback;
}

class _UserBusinessProfile {
  const _UserBusinessProfile({
    required this.region,
    required this.regionCode,
    required this.department,
    required this.departmentCode,
    required this.city,
  });

  final String region;
  final String regionCode;
  final String department;
  final String departmentCode;
  final String city;
}

extension _EmptyStringFallback on String {
  String ifEmpty(String fallback) {
    return trim().isEmpty ? fallback : this;
  }
}
