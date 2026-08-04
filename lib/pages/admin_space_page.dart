import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:presto_app/admin/listings/admin_listings_management_page.dart';
import 'package:presto_app/admin/messaging/admin_messaging_dashboard_page.dart';
import 'admin_hero_slides_page.dart';
import 'admin_messaging_moderation_page.dart';
import 'admin_photo_reviews_page.dart';
import 'admin_typography_page.dart';
import 'admin_monitoring_health_page.dart';
import '../models/admin_access_state.dart';
import '../utils/friendly_snackbar.dart';
import '../constants.dart';
import '../features/micro_ia/micro_ia_service.dart';
import '../features/subscriptions/subscription_widgets.dart';
import '../services/admin_access_resolver.dart';
import '../services/admin_broadcast_service.dart';
import '../services/firebase_functions_region.dart';
import '../services/notification_service.dart';
import 'package:presto_app/pages/admin/widgets/payment_info_audio_admin_section.dart';
import 'package:presto_app/pages/admin/ad_placeholder_images_admin_page.dart';

part 'admin_space/admin_space_deploy_diagnostic.dart';
part 'admin_space/admin_space_messaging_moderation.dart';
part 'admin_space/admin_space_metric_domains.dart';
part 'admin_space/admin_space_micro_ia_page.dart';
part 'admin_space/admin_space_formatters.dart';
part 'admin_space/admin_space_dashboard_windows.dart';
part 'admin_space/admin_space_dashboard_computed.dart';
part 'admin_space/admin_space_email_dashboard.dart';
part 'admin_space/admin_space_email_dashboard_content.dart';
part 'admin_space/admin_space_broadcast_page.dart';
part 'admin_space/admin_space_dashboard_section.dart';
part 'admin_space/admin_space_dashboard_cards.dart';
part 'admin_space/admin_space_profile_card.dart';
part 'admin_space/admin_space_state_widgets.dart';
part 'admin_space/admin_space_shell_widgets.dart';
part 'admin_space/admin_space_cards.dart';
part 'admin_space/admin_space_micro_ia_card.dart';
part 'admin_space/admin_space_chips.dart';

class AdminSpacePage extends StatefulWidget {
  const AdminSpacePage({super.key});

  @override
  State<AdminSpacePage> createState() => _AdminSpacePageState();
}

class _AdminSpacePageState extends State<AdminSpacePage> {
  static const Color prestoOrange = Color(0xFFFF6600);
  static const Color prestoBlue = Color(0xFF1A73E8);

  final FirebaseFunctions _functions = prestoFirebaseFunctions;
  final AdminAccessResolver _adminAccessResolver = AdminAccessResolver();
  final TextEditingController _deployDiagnosticController =
      TextEditingController();

  bool _adminStatusLoading = true;
  bool _adminAccessGranted = false;
  String _adminMode = 'HYBRID';
  String _adminAccessSource = '';
  DateTime? _adminCheckedAt;
  Object? _adminStatusError;
  AdminAccessState? _adminAccessState;
  bool _userStatsLoading = true;
  Map<String, dynamic>? _userStats;
  _AdminKpiSnapshot? _kpiSnapshot;

  void _onKpiComputed(_AdminKpiSnapshot snapshot) {
    if (mounted) setState(() => _kpiSnapshot = snapshot);
  }

  @override
  void initState() {
    super.initState();
    _reloadAdminPage();
  }

  @override
  void dispose() {
    _deployDiagnosticController.dispose();
    super.dispose();
  }

  Future<User?> _ensureSignedInUser({bool forceRefreshToken = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return null;
    }

    try {
      await user.getIdToken(forceRefreshToken);
    } catch (e) {
      debugPrint('[AdminSpace] getIdToken failed: $e');
    }

    return FirebaseAuth.instance.currentUser ?? user;
  }

  Future<void> _reloadAdminPage() async {
    await _loadAdminStatus();
    if (!mounted || !_adminAccessGranted) {
      if (mounted) {
        setState(() {
          _userStatsLoading = false;
        });
      }
      return;
    }
    await _loadUserStats();
  }

  Future<void> _loadAdminStatus() async {
    setState(() {
      _adminStatusLoading = true;
      _adminAccessGranted = false;
      _adminAccessSource = '';
      _adminStatusError = null;
      _adminAccessState = null;
    });

    try {
      final accessState = await _adminAccessResolver
          .resolveAdminAccess(
        forceRefresh: true,
        returnOnLocalAdminEvidence: true,
      )
          .timeout(
        const Duration(seconds: 6),
        onTimeout: () {
          throw TimeoutException(
            'admin verification timed out after 6 seconds',
          );
        },
      );
      if (!mounted) return;
      setState(() {
        _adminAccessState = accessState;
        _adminAccessGranted = accessState.effectiveIsAdmin;
        _adminAccessSource = accessState.sourceOfTruth == 'none'
            ? ''
            : accessState.sourceOfTruth;
        _adminCheckedAt = accessState.serverCheckedAt ?? _adminCheckedAt;
        _adminStatusError = accessState.effectiveIsAdmin
            ? null
            : StateError(
                accessState.isAuthenticated
                    ? 'permission-denied: admin required'
                    : 'unauthenticated: no current user',
              );
      });
      debugPrint(
        '[AdminSpace] adminCheckComplete=true uid=${accessState.uid ?? '-'} '
        'isAdmin=${accessState.effectiveIsAdmin} '
        'source=${accessState.sourceOfTruth} '
        'tokenAdmin=${accessState.tokenHasAdmin} '
        'profileAdmin=${accessState.profileHasAdmin} '
        'loading=false',
      );

      if (!accessState.effectiveIsAdmin) {
        return;
      }

      try {
        await MicroIaService.prepareSecureCallableContext(
          forceRefreshToken: true,
          forceRefreshAppCheckToken: true,
        );
        final configCallable = _functions.httpsCallable(
          'adminGetMicroIaConfig',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        );
        HttpsCallableResult<dynamic> configRes;
        try {
          configRes = await configCallable.call<dynamic>({});
        } on FirebaseFunctionsException catch (e) {
          if (e.code != 'unauthenticated' && e.code != 'permission-denied') {
            rethrow;
          }
          await MicroIaService.prepareSecureCallableContext(
            forceRefreshToken: true,
            forceRefreshAppCheckToken: true,
          );
          configRes = await configCallable.call<dynamic>({});
        }
        final configData = (configRes.data is Map)
            ? Map<String, dynamic>.from(configRes.data as Map)
            : <String, dynamic>{};
        if (!mounted) return;
        setState(() {
          _adminMode = (configData['mode'] ?? _adminMode).toString();
        });
      } catch (e) {
        debugPrint('[AdminSpace] adminGetMicroIaConfig failed: $e');
      }
    } catch (error) {
      if (!mounted) return;
      debugPrint(
        '[AdminSpace] adminCheckComplete=true isAdmin=false error=$error',
      );
      setState(() {
        _adminAccessGranted = false;
        _adminStatusError = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _adminStatusLoading = false;
        });
      }
    }
  }

  bool _isAdminAccessDenied(Object? error) {
    if (error is FirebaseFunctionsException) {
      return error.code == 'permission-denied' ||
          error.code == 'unauthenticated';
    }

    final errStr = error?.toString() ?? '';
    return errStr.contains('permission-denied') ||
        errStr.contains('unauthenticated');
  }

  String _adminErrorDetail(Object? error) {
    if (error is FirebaseFunctionsException) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }

      switch (error.code) {
        case 'permission-denied':
          return 'Accès refusé par la fonction admin.';
        case 'unauthenticated':
          return 'Session non synchronisee avec le serveur. Recharge la page ou reconnecte-toi.';
        case 'unavailable':
          return 'Le service admin est indisponible ou le réseau ne répond pas.';
        case 'deadline-exceeded':
          return 'La vérification admin a dépassé le délai autorisé.';
        case 'internal':
          return 'La fonction admin a renvoyé une erreur interne.';
      }
    }

    final errStr = error?.toString().trim() ?? '';
    final errLower = errStr.toLowerCase();
    if (errLower.contains('socketexception') ||
        errLower.contains('network') ||
        errLower.contains('failed host lookup')) {
      return 'Échec réseau pendant la vérification admin.';
    }
    if (errLower.contains('timeout') ||
        errLower.contains('deadline-exceeded')) {
      return 'La vérification admin a expiré.';
    }
    if (errStr.isEmpty) {
      return 'Détail indisponible.';
    }
    return errStr;
  }

  String _adminModeLabel(String mode) {
    switch (mode) {
      case 'GOOGLE_ONLY':
        return 'Google uniquement';
      case 'WHISPER_ONLY':
        return 'Whisper uniquement';
      case 'HYBRID':
      default:
        return 'Hybride';
    }
  }

  List<_FirebaseDeployDiagnosticRule> _matchFirebaseDeployDiagnostics(
    String rawOutput,
  ) {
    final normalized = rawOutput.toLowerCase();
    return _kFirebaseDeployDiagnosticRules.where((rule) {
      return rule.needles.any(normalized.contains);
    }).toList();
  }

  Widget _buildFirebaseDeployDiagnosticPanel() {
    final rawOutput = _deployDiagnosticController.text.trim();
    final matches = _matchFirebaseDeployDiagnostics(rawOutput);
    final hasOutput = rawOutput.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_sync_rounded, color: prestoBlue),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Diagnostic Firebase deploy',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: _kFirestoreRulesDeployCommand),
                  );
                  if (!mounted) return;
                  showSuccessSnackBar(context, 'Commande Firebase copiée');
                },
                icon: const Icon(Icons.copy_all_rounded, size: 16),
                label: const Text('Copier la commande'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Colle ici la sortie du terminal Codespaces pour mapper l’erreur de deploy vers une cause probable et une action utile.',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              _kFirestoreRulesDeployCommand,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _deployDiagnosticController,
            minLines: 5,
            maxLines: 8,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText:
                  'Colle ici la sortie firebase deploy --only firestore:rules',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: hasOutput
                    ? () {
                        _deployDiagnosticController.clear();
                        setState(() {});
                      }
                    : null,
                icon: const Icon(Icons.clear_rounded),
                label: const Text('Vider'),
              ),
              const SizedBox(width: 10),
              if (hasOutput)
                Text(
                  matches.isEmpty
                      ? 'Aucun motif connu détecté'
                      : '${matches.length} diagnostic${matches.length > 1 ? 's' : ''} détecté${matches.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: matches.isEmpty ? Colors.black45 : prestoBlue,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasOutput)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kFirebaseDeployDiagnosticRules.take(4).map((rule) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: rule.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    rule.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: rule.color,
                    ),
                  ),
                );
              }).toList(),
            ),
          if (hasOutput && matches.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
              child: const Text(
                'La sortie ne correspond pas à un motif connu. Vérifie le project id, le compte CLI, le fichier firestore.rules et la connectivité réseau.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            ),
          if (matches.isNotEmpty) ...[
            for (final rule in matches) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: rule.color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: rule.color.withValues(alpha: 0.22)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(rule.icon, color: rule.color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            rule.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rule.summary,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Action: ${rule.action}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAdminStatusBanner() {
    if (_adminStatusLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: prestoBlue.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: prestoBlue.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Verification admin en cours pour cet espace.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_adminStatusError != null) {
      final denied = _isAdminAccessDenied(_adminStatusError);
      final detail = _adminAccessSource.isNotEmpty
          ? 'Source serveur: $_adminAccessSource'
          : _adminErrorDetail(_adminStatusError);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: denied ? Colors.red.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: denied ? Colors.red.shade200 : Colors.orange.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              denied
                  ? 'Acces admin non confirme'
                  : 'Controle admin indisponible',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              denied
                  ? 'Le chargement admin n est pas encore confirme pour cette session. Relance le controle apres synchronisation.'
                  : 'La verification admin a echoue temporairement. Relance le controle.',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Detail: $detail',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black45,
                fontSize: 12,
              ),
            ),
            if (_adminCheckedAt != null) ...[
              const SizedBox(height: 6),
              Text(
                'Dernier controle valide: ${_formatAdminTimestamp(_adminCheckedAt!.millisecondsSinceEpoch)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black45,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _reloadAdminPage,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Relancer le controle'),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: prestoBlue.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Colors.green.shade700),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Statut admin verifie',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  'Verifie',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Mode serveur charge: ${_adminModeLabel(_adminMode)}.',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          if (_adminAccessState != null &&
              _adminAccessState!.serverCheckAttempted &&
              !_adminAccessState!.serverCheckSucceeded) ...[
            const SizedBox(height: 6),
            Text(
              'Vérification serveur temporairement indisponible, accès confirmé par ${_adminAccessSource.isNotEmpty ? _adminAccessSource : 'une source locale'}.',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade700,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Dernier controle: ${_formatAdminTimestamp(_adminCheckedAt?.millisecondsSinceEpoch)}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black45,
              fontSize: 12,
            ),
          ),
          if (_adminAccessSource.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Source droits admin: $_adminAccessSource',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black45,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: prestoBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Config Micro-IA chargee',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: prestoBlue.withValues(alpha: 0.92),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: prestoOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Pipeline: ${_adminModeLabel(_adminMode)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: prestoOrange.withValues(alpha: 0.92),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserStats() async {
    setState(() => _userStatsLoading = true);
    if (!_adminAccessGranted) {
      setState(() => _userStatsLoading = false);
      return;
    }
    try {
      final signedInUser = await _ensureSignedInUser(forceRefreshToken: true);
      if (signedInUser == null) {
        throw StateError('unauthenticated: no current user');
      }

      final callable = _functions.httpsCallable(
        'adminGetUserStats',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
      );
      final res = await callable.call<dynamic>({});
      final data = (res.data is Map)
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _userStats = data;
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        final user = await _ensureSignedInUser(forceRefreshToken: true);
        if (user != null) {
          try {
            final callable = _functions.httpsCallable(
              'adminGetUserStats',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 15),
              ),
            );
            final res = await callable.call<dynamic>({});
            final data = (res.data is Map)
                ? Map<String, dynamic>.from(res.data as Map)
                : <String, dynamic>{};
            if (!mounted) return;
            setState(() {
              _userStats = data;
            });
            return;
          } catch (_) {}
        }
      }
      if (!mounted) return;
      showErrorSnackBar(context, e.message ?? 'Erreur stats utilisateurs');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur stats utilisateurs: $e');
    } finally {
      if (mounted) setState(() => _userStatsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final totalAccounts = (_userStats?['totalAccounts'] as num?)?.toInt();
    final onlineUsers = (_userStats?['onlineUsers'] as num?)?.toInt();
    final proLogins = (_userStats?['proLogins'] as num?)?.toInt();
    final windowMinutes = (_userStats?['windowMinutes'] as num?)?.toInt();

    final usersSubtitle = _userStatsLoading
        ? 'Chargement…'
        : (totalAccounts == null || onlineUsers == null || proLogins == null)
            ? '—'
            : 'Total: $totalAccounts\nEn ligne: $onlineUsers (${windowMinutes ?? 5} min)\nConnexions Pro: $proLogins';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: const Text('Espace admin', style: kPrestoAppBarTitleStyle),
        actions: [
          _AdminChip(
            label: 'Admin',
            onTap: () {
              unawaited(_reloadAdminPage());
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gestion & configuration',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                "Paramètres système, modération et outils d’administration.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 14),
              _ProfileCard(
                prestoBlue: prestoBlue,
                uid: user?.uid ?? '(non connecté)',
                role: 'Admin',
                lastLoginLabel: user?.metadata.lastSignInTime == null
                    ? 'Dernière connexion : (inconnue)'
                    : 'Dernière connexion : ${user!.metadata.lastSignInTime!.toLocal().toIso8601String()}',
                onCopyUid: () async {
                  await Clipboard.setData(ClipboardData(text: user?.uid ?? ''));
                  if (!context.mounted) return;
                  showSuccessSnackBar(context, 'UID copié');
                },
              ),
              const SizedBox(height: 14),
              _buildAdminStatusBanner(),
              const SizedBox(height: 14),
              const AdminSubscriptionTile(),
              const SizedBox(height: 14),
              const _AdminMessagingModerationTile(),
              const SizedBox(height: 14),
              _AdminMessagingEntryCard(accessState: _adminAccessState),
              const SizedBox(height: 14),
              _buildFirebaseDeployDiagnosticPanel(),
              const SizedBox(height: 14),
              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 150,
                ),
                children: [
                  _KpiTile(
                    icon: Icons.group_rounded,
                    title: 'Utilisateurs',
                    subtitle: usersSubtitle,
                    badge: null,
                    iconColor: prestoBlue,
                  ),
                  _KpiTile(
                    icon: Icons.campaign_rounded,
                    title: 'Offres',
                    subtitle: _kpiSnapshot == null
                        ? 'Chargement…'
                        : 'Actives: ${_formatCompactNumber(_kpiSnapshot!.activeListings)}\nTotal: ${_formatCompactNumber(_kpiSnapshot!.publishedListings)}\nExpirées: ${_formatCompactNumber(_kpiSnapshot!.expiredListings)}',
                    badge: null,
                    iconColor: prestoOrange,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminListingsManagementPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.chat_bubble_rounded,
                    title: 'Messages',
                    subtitle: _kpiSnapshot == null
                        ? 'Chargement…'
                        : _kpiSnapshot!.messagesStarted == 0
                            ? 'Aucun message\nenregistré'
                            : '${_formatCompactNumber(_kpiSnapshot!.messagesStarted)}\ndémarrés',
                    badge: null,
                    iconColor: prestoBlue,
                  ),
                  _KpiTile(
                    icon: Icons.verified_user_rounded,
                    title: 'Modération',
                    subtitle: _kpiSnapshot == null
                        ? 'Chargement…'
                        : (_kpiSnapshot!.reportedListings == 0 &&
                                _kpiSnapshot!.blockedListings == 0)
                            ? 'Aucune alerte\nen cours'
                            : 'Signalées: ${_formatCompactNumber(_kpiSnapshot!.reportedListings)}\nBloquées: ${_formatCompactNumber(_kpiSnapshot!.blockedListings)}\nEn revue: ${_formatCompactNumber(_kpiSnapshot!.manualReviewListings)}',
                    badge: null,
                    iconColor: prestoBlue,
                  ),
                  _KpiTile(
                    icon: Icons.admin_panel_settings_rounded,
                    title: 'Gestion messagerie',
                    subtitle: 'Dashboard, signalements, audit et réglages',
                    badge: null,
                    iconColor: const Color(0xFF0F766E),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AdminMessagingDashboardPage(
                            accessState: _adminAccessState,
                          ),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.shield_outlined,
                    title: 'Messages modérés',
                    subtitle: 'Journal récent\ndes messages en revue',
                    badge: null,
                    iconColor: const Color(0xFF0F766E),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminMessagingModerationPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.photo_library_outlined,
                    title: 'Photos à valider',
                    subtitle: 'Swipe gauche / droite',
                    badge: null,
                    iconColor: prestoOrange,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminPhotoReviewsPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.workspace_premium_rounded,
                    title: 'Premium',
                    subtitle: _kpiSnapshot == null
                        ? 'Chargement…'
                        : 'Abonnements: ${_formatCompactNumber(_kpiSnapshot!.activeSubscriptions)}\nUpgrades: ${_formatCompactNumber(_kpiSnapshot!.premiumUpgrades)}',
                    badge: null,
                    iconColor: prestoOrange,
                  ),
                  _EmailSummaryTile(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const EmailDashboardPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.tune_rounded,
                    title: 'Remote Config',
                    subtitle: 'Réglages IA',
                    badge: null,
                    iconColor: prestoBlue,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MicroIaTranscriptionPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.monitor_heart_rounded,
                    title: 'Monitoring',
                    subtitle: 'Santé app',
                    badge: null,
                    iconColor: prestoOrange,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminMonitoringHealthPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.slideshow_rounded,
                    title: "Gestion du Hero",
                    subtitle: "Accueil: ajouter, supprimer et réordonner",
                    badge: null,
                    iconColor: prestoOrange,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminHeroSlidesPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.photo_library_outlined,
                    title: 'Images placeholders',
                    subtitle: 'AdBanner Je consulte',
                    badge: null,
                    iconColor: prestoOrange,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdPlaceholderImagesAdminPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.headphones_rounded,
                    title: "Audio popup",
                    subtitle: "Génération & import MP3",
                    badge: null,
                    iconColor: prestoBlue,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const _AudioPopupAdminPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.notifications_active_rounded,
                    title: "Notification test",
                    subtitle: "Push à tous les utilisateurs",
                    badge: null,
                    iconColor: prestoOrange,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const _BroadcastNotificationAdminPage(),
                        ),
                      );
                    },
                  ),
                  _KpiTile(
                    icon: Icons.text_fields_rounded,
                    title: "Typographie",
                    subtitle: "Police et taille pour toute l'application",
                    badge: null,
                    iconColor: prestoBlue,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminTypographyPage(),
                        ),
                      );
                    },
                  ),
                  if (!kReleaseMode)
                    _KpiTile(
                      icon: Icons.layers_rounded,
                      title: 'Catalogue pages',
                      subtitle: 'Inventaire et rendu par page',
                      badge: null,
                      iconColor: prestoBlue,
                      onTap: () {
                        Navigator.of(context).pushNamed('/page-catalog');
                      },
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _AdminDashboardSection(
                userStats: _userStats,
                userStatsLoading: _userStatsLoading,
                domains: _kAdminDashboardMetricDomains,
                onComputed: _onKpiComputed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
