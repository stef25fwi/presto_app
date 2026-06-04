import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_check_state.dart';
import '../models/admin_access_state.dart';
import '../services/admin_audio_runtime_store.dart';
import '../services/admin_access_resolver.dart';
import '../services/admin_web_debug_store.dart';

class AdminWebDebugPanel extends StatefulWidget {
  const AdminWebDebugPanel({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AdminWebDebugPanel> createState() => _AdminWebDebugPanelState();
}

class _AdminWebDebugPanelState extends State<AdminWebDebugPanel> {
  final AdminAccessResolver _adminAccessResolver = AdminAccessResolver();
  final AdminAudioRuntimeStore _audioRuntimeStore =
      AdminAudioRuntimeStore.instance;
  final AdminWebDebugStore _debugStore = AdminWebDebugStore.instance;
  StreamSubscription<User?>? _authSubscription;
  bool _isExpanded = false;
  bool _isRefreshingAdmin = false;
  String _selectedArea = 'all';
  bool _callableOnly = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) return;
    _debugStore.updateAuth(FirebaseAuth.instance.currentUser);
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _debugStore.updateAuth(user);
      unawaited(_refreshAdminAccess());
    });
    unawaited(_audioRuntimeStore.ensureInitialized());
    unawaited(_refreshAdminAccess());
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshAdminAccess() async {
    if (_isRefreshingAdmin || !kIsWeb) return;
    _isRefreshingAdmin = true;
    try {
      final state = await _adminAccessResolver.resolveAdminAccess(
        returnOnLocalAdminEvidence: true,
      );
      _debugStore.updateAdminAccess(state);
    } catch (error, stackTrace) {
      _debugStore.recordError(
        'admin',
        error,
        stackTrace: stackTrace,
        message: 'admin-access-refresh-failed',
      );
    } finally {
      _isRefreshingAdmin = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _copyReport(BuildContext context) async {
    final report = _debugStore.buildExportReport(
      area: _selectedArea == 'all' ? null : _selectedArea,
      callableOnly: _callableOnly,
    );
    await _copyToClipboard(
      context,
      text: report,
      successMessage: 'Diagnostic copié dans le presse-papiers.',
    );
  }

  Future<void> _copyJsonReport(BuildContext context) async {
    final report = _debugStore.buildExportJson(
      area: _selectedArea == 'all' ? null : _selectedArea,
      callableOnly: _callableOnly,
    );
    await _copyToClipboard(
      context,
      text: report,
      successMessage: 'Diagnostic JSON copié dans le presse-papiers.',
    );
  }

  Future<void> _copyToClipboard(
    BuildContext context, {
    required String text,
    required String successMessage,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(successMessage)),
    );
  }

  void _syncRoute(BuildContext context) {
    final routeName =
        ModalRoute.of(context)?.settings.name?.trim() ?? Uri.base.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _debugStore.updateRoute(routeName);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return widget.child;

    _syncRoute(context);

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        _debugStore,
        _audioRuntimeStore,
      ]),
      builder: (context, _) {
        final adminState = _debugStore.adminAccessState;
        if (!adminState.hasConfirmedAdminAccess) {
          return widget.child;
        }
        if (!_isExpanded && _debugStore.hasPendingAutoOpenRequest) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_debugStore.consumeAutoOpenRequest()) return;
            setState(() {
              _isExpanded = true;
            });
          });
        }

        return Stack(
          children: [
            widget.child,
            Positioned(
              right: 12,
              bottom: 12,
              child: SafeArea(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isExpanded) _buildExpandedPanel(context, adminState),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF111827),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        icon: Icon(
                          _isExpanded
                              ? Icons.bug_report_outlined
                              : Icons.monitor_heart_outlined,
                        ),
                        label: Text(
                          _isExpanded
                              ? 'Masquer debug admin'
                              : 'Debug admin web',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExpandedPanel(BuildContext context, AdminAccessState adminState) {
    final host = currentAppCheckWebHost();
    final hostClass = appCheckWebHostClass(host);
    final activationError = appCheckActivationError?.toString().trim() ?? '';
    final refreshError = appCheckLastTokenRefreshError?.toString().trim() ?? '';
    final latestAudio = _audioRuntimeStore.latestEntry;
    final areaOptions = <String>['all', ..._debugStore.availableAreas];
    if (!areaOptions.contains(_selectedArea)) {
      _selectedArea = 'all';
    }
    final events = _debugStore
        .filteredEvents(
          area: _selectedArea == 'all' ? null : _selectedArea,
          callableOnly: _callableOnly,
        )
        .take(24)
        .toList(growable: false);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD1D5DB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 12,
            height: 1.35,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Diagnostic admin web',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Rafraichir droits admin',
                    onPressed: _refreshAdminAccess,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(
                    tooltip: 'Vider les evenements',
                    onPressed: _debugStore.clear,
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
                  IconButton(
                    tooltip: 'Copier le diagnostic',
                    onPressed: () => _copyReport(context),
                    icon: const Icon(Icons.copy_all_rounded),
                  ),
                  IconButton(
                    tooltip: 'Copier le diagnostic JSON',
                    onPressed: () => _copyJsonReport(context),
                    icon: const Icon(Icons.data_object_rounded),
                  ),
                ],
              ),
              _buildSection(
                'Contexte',
                <String>[
                  'route=${_debugStore.currentRoute}',
                  'host=$host class=$hostClass',
                  'user=${_debugStore.currentUserId ?? 'null'} ${_debugStore.currentUserEmail ?? ''}'.trim(),
                ],
              ),
              _buildSection(
                'Admin',
                <String>[
                  'access=${adminState.hasConfirmedAdminAccess}',
                  'source=${adminState.consolidatedSourceOfTruth}',
                  'stage=${adminState.lastStage}',
                  if ((adminState.serverErrorCode ?? '').toString().isNotEmpty)
                    'serverError=${adminState.serverErrorCode}',
                ],
              ),
              _buildSection(
                'App Check',
                <String>[
                  'attempted=$appCheckActivationAttempted success=$appCheckActivationSucceeded',
                  'provider=$kAppCheckWebRecaptchaProviderLabel siteKeySet=${kAppCheckWebRecaptchaSiteKey.trim().isNotEmpty}',
                  'lastRefresh=${_formatTime(appCheckLastTokenRefreshAt)}',
                  if (activationError.isNotEmpty) 'activationError=$activationError',
                  if (refreshError.isNotEmpty) 'refreshError=$refreshError',
                ],
              ),
              _buildSection(
                'Runtime IA',
                <String>[
                  'configuredMode=${_audioRuntimeStore.configuredMode}',
                  'current=${_audioRuntimeStore.currentLabel}',
                  'detail=${_audioRuntimeStore.currentDetail}',
                  if (latestAudio != null)
                    'latest=${latestAudio.flowKey} ${latestAudio.status} #${latestAudio.attemptNumber}',
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Timeline',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final area in areaOptions)
                    ChoiceChip(
                      label: Text(area == 'all' ? 'Toutes zones' : area),
                      selected: _selectedArea == area,
                      onSelected: (_) {
                        setState(() {
                          _selectedArea = area;
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  FilterChip(
                    label: Text(
                      _callableOnly
                          ? 'Callables uniquement'
                          : 'Tous evenements + callables',
                    ),
                    avatar: const Icon(Icons.cloud_done_outlined, size: 18),
                    selected: _callableOnly,
                    onSelected: (selected) {
                      setState(() {
                        _callableOnly = selected;
                      });
                    },
                  ),
                  if (_callableOnly)
                    Text(
                      '${events.length} evenement(s) affiché(s)',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _colorForLevel(event.level),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '[${_formatTime(event.timestamp)}] '
                              '${event.area}/${event.level} ${event.message}'
                              '${event.detail == null || event.detail!.isEmpty ? '' : '\n${event.detail}'}',
                              style: TextStyle(
                                fontSize: 11,
                                color: event.level == 'error'
                                    ? const Color(0xFF991B1B)
                                    : const Color(0xFF111827),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> lines) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(line),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  Color _colorForLevel(String level) {
    switch (level) {
      case 'error':
        return const Color(0xFFDC2626);
      case 'warn':
        return const Color(0xFFF59E0B);
      case 'success':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF2563EB);
    }
  }
}