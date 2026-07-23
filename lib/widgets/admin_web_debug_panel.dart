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

  Future<void> _copyLogContent(BuildContext context) async {
    final logs = _debugStore.filteredEvents(
      area: _selectedArea == 'all' ? null : _selectedArea,
      callableOnly: _callableOnly,
    );
    final text = _buildLogClipboardText(logs);
    await _copyToClipboard(
      context,
      text: text,
      successMessage: 'Logs copies dans le presse-papiers.',
    );
  }

  String _buildLogClipboardText(List<AdminWebDebugEvent> logs) {
    if (logs.isEmpty) {
      return 'Aucun log pour le filtre actif.';
    }

    final lines = <String>[];
    for (final event in logs) {
      lines.add(
        '[${event.timestamp.toIso8601String()}] '
        '${event.area}/${event.level}${event.isCallable ? '/callable' : ''} ${event.message}',
      );
      final detail = (event.detail ?? '').toString().trim();
      if (detail.isNotEmpty) {
        lines.add('  $detail');
      }
    }
    return lines.join('\n');
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

        final screenWidth = MediaQuery.of(context).size.width;
        final panelWidth =
            screenWidth < 500 ? (screenWidth * 0.9).clamp(280.0, 380.0) : 440.0;
        final isSmallScreen = screenWidth < 500;

        return Stack(
          children: [
            widget.child,
            Positioned(
              right: isSmallScreen ? 8 : 12,
              top: isSmallScreen ? 8 : 12,
              child: SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: panelWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSmallScreen)
                        IconButton.filled(
                          tooltip: _isExpanded
                              ? 'Masquer le diagnostic admin'
                              : 'Ouvrir le diagnostic admin',
                          onPressed: () {
                            setState(() {
                              _isExpanded = !_isExpanded;
                            });
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF111827),
                            foregroundColor: Colors.white,
                          ),
                          icon: Icon(
                            _isExpanded
                                ? Icons.close_rounded
                                : Icons.monitor_heart_outlined,
                            size: 20,
                          ),
                        )
                      else
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
                            size: 20,
                          ),
                          label: Text(
                            _isExpanded
                                ? 'Masquer debug admin'
                                : 'Debug admin web',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      if (_isExpanded) ...[
                        const SizedBox(height: 8),
                        _buildExpandedPanel(context, adminState, isSmallScreen),
                      ],
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

  Widget _buildExpandedPanel(
      BuildContext context, AdminAccessState adminState, bool isSmallScreen) {
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

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.of(context).size.height * (isSmallScreen ? 0.65 : 0.75),
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
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
            style: TextStyle(
              color: const Color(0xFF111827),
              fontSize: isSmallScreen ? 11 : 12,
              height: 1.35,
            ),
            child: SingleChildScrollView(
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
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!isSmallScreen) ...[
                        IconButton(
                          tooltip: 'Rafraichir droits admin',
                          onPressed: _refreshAdminAccess,
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                        IconButton(
                          tooltip: 'Vider les evenements',
                          onPressed: _debugStore.clear,
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.delete_sweep_outlined),
                        ),
                        IconButton(
                          tooltip: 'Copier le diagnostic',
                          onPressed: () => _copyReport(context),
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.copy_all_rounded),
                        ),
                        IconButton(
                          tooltip: 'Copier le diagnostic JSON',
                          onPressed: () => _copyJsonReport(context),
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.data_object_rounded),
                        ),
                        IconButton(
                          tooltip: 'Copier le contenu des logs',
                          onPressed: () => _copyLogContent(context),
                          iconSize: 18,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.content_copy_rounded),
                        ),
                      ] else ...[
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 18),
                            onSelected: (action) {
                              if (action == 'refresh') {
                                _refreshAdminAccess();
                              } else if (action == 'clear') {
                                _debugStore.clear();
                              } else if (action == 'copy') {
                                _copyReport(context);
                              } else if (action == 'copy-json') {
                                _copyJsonReport(context);
                              } else if (action == 'copy-logs') {
                                _copyLogContent(context);
                              }
                            },
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<String>>[
                              const PopupMenuItem(
                                value: 'refresh',
                                child: Row(
                                  children: [
                                    Icon(Icons.refresh_rounded, size: 16),
                                    SizedBox(width: 8),
                                    Text('Rafraichir',
                                        style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'clear',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_sweep_outlined, size: 16),
                                    SizedBox(width: 8),
                                    Text('Vider',
                                        style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'copy',
                                child: Row(
                                  children: [
                                    Icon(Icons.copy_all_rounded, size: 16),
                                    SizedBox(width: 8),
                                    Text('Copier',
                                        style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'copy-json',
                                child: Row(
                                  children: [
                                    Icon(Icons.data_object_rounded, size: 16),
                                    SizedBox(width: 8),
                                    Text('JSON',
                                        style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'copy-logs',
                                child: Row(
                                  children: [
                                    Icon(Icons.content_copy_rounded, size: 16),
                                    SizedBox(width: 8),
                                    Text('Logs',
                                        style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 6 : 8),
                  _buildSection(
                    'Contexte',
                    <String>[
                      'route=${_debugStore.currentRoute}',
                      'host=$host class=$hostClass',
                      'user=${_debugStore.currentUserId ?? 'null'} ${_debugStore.currentUserEmail ?? ''}'
                          .trim(),
                    ],
                  ),
                  _buildSection(
                    'Admin',
                    <String>[
                      'access=${adminState.hasConfirmedAdminAccess}',
                      'source=${adminState.consolidatedSourceOfTruth}',
                      'stage=${adminState.lastStage}',
                      if ((adminState.serverErrorCode ?? '')
                          .toString()
                          .isNotEmpty)
                        'serverError=${adminState.serverErrorCode}',
                    ],
                  ),
                  _buildSection(
                    'App Check',
                    <String>[
                      'attempted=$appCheckActivationAttempted success=$appCheckActivationSucceeded',
                      'provider=$kAppCheckWebRecaptchaProviderLabel siteKeySet=${kAppCheckWebRecaptchaSiteKey.trim().isNotEmpty}',
                      'lastRefresh=${_formatTime(appCheckLastTokenRefreshAt)}',
                      if (activationError.isNotEmpty)
                        'activationError=$activationError',
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
                  SizedBox(height: isSmallScreen ? 6 : 8),
                  Row(
                    children: [
                      Text(
                        'Timeline',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: isSmallScreen ? 11 : 12,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 26,
                        height: 26,
                        child: IconButton(
                          tooltip: 'Copier les logs',
                          padding: EdgeInsets.zero,
                          iconSize: 15,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.content_copy_rounded),
                          onPressed: () => _copyLogContent(context),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 4 : 6),
                  Wrap(
                    spacing: isSmallScreen ? 4 : 6,
                    runSpacing: isSmallScreen ? 4 : 6,
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
                          labelStyle:
                              TextStyle(fontSize: isSmallScreen ? 10 : 11),
                          materialTapTargetSize: isSmallScreen
                              ? MaterialTapTargetSize.shrinkWrap
                              : MaterialTapTargetSize.padded,
                        ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 6 : 8),
                  Wrap(
                    spacing: isSmallScreen ? 4 : 6,
                    runSpacing: isSmallScreen ? 4 : 6,
                    children: [
                      FilterChip(
                        label: Text(
                          _callableOnly
                              ? 'Callables uniquement'
                              : 'Tous evenements',
                          style: TextStyle(fontSize: isSmallScreen ? 10 : 11),
                        ),
                        avatar: Icon(Icons.cloud_done_outlined,
                            size: isSmallScreen ? 14 : 18),
                        selected: _callableOnly,
                        onSelected: (selected) {
                          setState(() {
                            _callableOnly = selected;
                          });
                        },
                        materialTapTargetSize: isSmallScreen
                            ? MaterialTapTargetSize.shrinkWrap
                            : MaterialTapTargetSize.padded,
                      ),
                      if (_callableOnly)
                        Text(
                          '${events.length} evt',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 9 : 11,
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 6 : 8),
                  ConstrainedBox(
                    constraints:
                        BoxConstraints(maxHeight: isSmallScreen ? 200 : 260),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.symmetric(
                            horizontal: 6, vertical: isSmallScreen ? 6 : 8),
                        itemCount: events.length,
                        separatorBuilder: (_, __) => const Divider(height: 10),
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 3),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _colorForLevel(event.level),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: isSmallScreen ? 6 : 8),
                              Expanded(
                                child: Text(
                                  '[${_formatTime(event.timestamp)}] '
                                  '${event.area}/${event.level} ${event.message}'
                                  '${event.detail == null || event.detail!.isEmpty ? '' : '\n${event.detail}'}',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 10 : 11,
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
