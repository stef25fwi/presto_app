import { readFile, writeFile } from 'node:fs/promises';

const replacements = [
  {
    path: 'lib/features/subscriptions/subscription_widgets.dart',
    before: `  Future<void> _toggleVisibility(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.updateSectionVisibility(
        enabled,
        updatedBy: FirebaseAuth.instance.currentUser?.uid,
      );
      if (mounted)
        showSuccessSnackBar(context, 'Visibilité des abonnements mise à jour.');
    } catch (_) {
      if (mounted)
        showErrorSnackBar(
          context,
          'Impossible de mettre à jour la configuration.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleFreeAccess(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.updateFreeAccessMode(
        enabled,
        updatedBy: FirebaseAuth.instance.currentUser?.uid,
      );
      if (mounted)
        showSuccessSnackBar(context, 'Mode d’accès abonnement mis à jour.');
    } catch (_) {
      if (mounted)
        showErrorSnackBar(
          context,
          'Impossible de mettre à jour freeAccessMode.',
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }`,
    after: `  Future<void> _toggleVisibility(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.updateSectionVisibility(
        enabled,
        updatedBy: FirebaseAuth.instance.currentUser?.uid,
      );
      if (mounted) {
        showSuccessSnackBar(context, 'Visibilité des abonnements mise à jour.');
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Impossible de mettre à jour la configuration.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _toggleFreeAccess(bool enabled) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.updateFreeAccessMode(
        enabled,
        updatedBy: FirebaseAuth.instance.currentUser?.uid,
      );
      if (mounted) {
        showSuccessSnackBar(context, 'Mode d’accès abonnement mis à jour.');
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(
          context,
          'Impossible de mettre à jour freeAccessMode.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }`,
  },
  {
    path: 'lib/pages/fiche_pro_page.dart',
    before: `      if (mounted) setState(() => _realisations.remove(url));
    } catch (_) {
      if (mounted)
        showErrorSnackBar(context, 'Impossible de supprimer la photo.');
    }`,
    after: `      if (mounted) {
        setState(() => _realisations.remove(url));
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, 'Impossible de supprimer la photo.');
      }
    }`,
  },
  {
    path: 'lib/services/hero_slides_service.dart',
    before: `        if (slide.isGlobal) return true;
        if (slide.isRegional) {
          if (normalizedRegion == null || normalizedRegion.isEmpty)
            return false;
          if (slide.targetRegions.isEmpty) return false;
          return slide.targetRegions.contains(normalizedRegion);
        }`,
    after: `        if (slide.isGlobal) return true;
        if (slide.isRegional) {
          if (normalizedRegion == null || normalizedRegion.isEmpty) {
            return false;
          }
          if (slide.targetRegions.isEmpty) return false;
          return slide.targetRegions.contains(normalizedRegion);
        }`,
  },
  {
    path: 'lib/services/journey_pdf_export_service.dart',
    before: `    if (cleaned.isEmpty || cleaned == 'null')
      return pw.SizedBox(width: 0, height: 0);
    return pw.Padding(`,
    after: `    if (cleaned.isEmpty || cleaned == 'null') {
      return pw.SizedBox(width: 0, height: 0);
    }
    return pw.Padding(`,
  },
  {
    path: 'lib/services/value_analysis_service.dart',
    before: `    // More views = higher confidence
    if (params.viewCount > 100)
      score += 15;
    else if (params.viewCount > 50)
      score += 10;
    else if (params.viewCount > 10)
      score += 5;

    // More favorites = higher confidence
    if (params.favoriteCount > 20)
      score += 15;
    else if (params.favoriteCount > 10)
      score += 10;
    else if (params.favoriteCount > 5)
      score += 5;

    // Known category = higher confidence
    if (_categoryResaleRetention.containsKey(params.category)) score += 10;

    // Recent listing = higher confidence
    if (params.itemAgeDays < 14) score += 10;

    // Premium listing = higher confidence in pricing
    if (params.isPremium) score += 5;`,
    after: `    // More views = higher confidence
    if (params.viewCount > 100) {
      score += 15;
    } else if (params.viewCount > 50) {
      score += 10;
    } else if (params.viewCount > 10) {
      score += 5;
    }

    // More favorites = higher confidence
    if (params.favoriteCount > 20) {
      score += 15;
    } else if (params.favoriteCount > 10) {
      score += 10;
    } else if (params.favoriteCount > 5) {
      score += 5;
    }

    // Known category = higher confidence
    if (_categoryResaleRetention.containsKey(params.category)) {
      score += 10;
    }

    // Recent listing = higher confidence
    if (params.itemAgeDays < 14) {
      score += 10;
    }

    // Premium listing = higher confidence in pricing
    if (params.isPremium) {
      score += 5;
    }`,
  },
];

for (const replacement of replacements) {
  const source = await readFile(replacement.path, 'utf8');
  if (!source.includes(replacement.before)) {
    if (source.includes(replacement.after)) continue;
    throw new Error(`curly-brace anchor not found in ${replacement.path}`);
  }
  await writeFile(
    replacement.path,
    source.replace(replacement.before, replacement.after),
    'utf8',
  );
}

console.log('curly brace analyzer fixes applied');
