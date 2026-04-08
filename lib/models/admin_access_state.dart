class AdminAccessState {
  final bool isAuthenticated;
  final String? uid;
  final String? email;
  final bool tokenLoaded;
  final bool tokenHasAdmin;
  final List<String> tokenRoles;
  final String? tokenPrimaryRole;
  final bool profileLoaded;
  final bool profileHasAdmin;
  final List<String> profileRoles;
  final String? profilePrimaryRole;
  final bool adminDocLoaded;
  final bool adminDocHasAdmin;
  final bool serverCheckAttempted;
  final bool serverCheckSucceeded;
  final bool? serverIsAdmin;
  final String? serverSource;
  final String? serverErrorCode;
  final String? serverErrorMessage;
  final DateTime? serverCheckedAt;
  final Map<String, dynamic> serverDebug;
  final bool effectiveIsAdmin;
  final String sourceOfTruth;
  final String lastStage;
  final List<String> debugSteps;

  const AdminAccessState({
    required this.isAuthenticated,
    required this.uid,
    required this.email,
    required this.tokenLoaded,
    required this.tokenHasAdmin,
    required this.tokenRoles,
    required this.tokenPrimaryRole,
    required this.profileLoaded,
    required this.profileHasAdmin,
    required this.profileRoles,
    required this.profilePrimaryRole,
    required this.adminDocLoaded,
    required this.adminDocHasAdmin,
    required this.serverCheckAttempted,
    required this.serverCheckSucceeded,
    required this.serverIsAdmin,
    required this.serverSource,
    required this.serverErrorCode,
    required this.serverErrorMessage,
    required this.serverCheckedAt,
    required this.serverDebug,
    required this.effectiveIsAdmin,
    required this.sourceOfTruth,
    required this.lastStage,
    required this.debugSteps,
  });

  factory AdminAccessState.initial() {
    return const AdminAccessState(
      isAuthenticated: false,
      uid: null,
      email: null,
      tokenLoaded: false,
      tokenHasAdmin: false,
      tokenRoles: <String>[],
      tokenPrimaryRole: null,
      profileLoaded: false,
      profileHasAdmin: false,
      profileRoles: <String>[],
      profilePrimaryRole: null,
      adminDocLoaded: false,
      adminDocHasAdmin: false,
      serverCheckAttempted: false,
      serverCheckSucceeded: false,
      serverIsAdmin: null,
      serverSource: null,
      serverErrorCode: null,
      serverErrorMessage: null,
      serverCheckedAt: null,
      serverDebug: <String, dynamic>{},
      effectiveIsAdmin: false,
      sourceOfTruth: 'none',
      lastStage: 'idle',
      debugSteps: <String>[],
    );
  }

  bool get hasLocalAdminEvidence {
    return tokenHasAdmin || profileHasAdmin || adminDocHasAdmin;
  }

  AdminAccessState copyWith({
    bool? isAuthenticated,
    String? uid,
    bool clearUid = false,
    String? email,
    bool clearEmail = false,
    bool? tokenLoaded,
    bool? tokenHasAdmin,
    List<String>? tokenRoles,
    String? tokenPrimaryRole,
    bool clearTokenPrimaryRole = false,
    bool? profileLoaded,
    bool? profileHasAdmin,
    List<String>? profileRoles,
    String? profilePrimaryRole,
    bool clearProfilePrimaryRole = false,
    bool? adminDocLoaded,
    bool? adminDocHasAdmin,
    bool? serverCheckAttempted,
    bool? serverCheckSucceeded,
    bool? serverIsAdmin,
    bool clearServerIsAdmin = false,
    String? serverSource,
    bool clearServerSource = false,
    String? serverErrorCode,
    bool clearServerErrorCode = false,
    String? serverErrorMessage,
    bool clearServerErrorMessage = false,
    DateTime? serverCheckedAt,
    bool clearServerCheckedAt = false,
    Map<String, dynamic>? serverDebug,
    bool? effectiveIsAdmin,
    String? sourceOfTruth,
    String? lastStage,
    List<String>? debugSteps,
  }) {
    return AdminAccessState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      uid: clearUid ? null : (uid ?? this.uid),
      email: clearEmail ? null : (email ?? this.email),
      tokenLoaded: tokenLoaded ?? this.tokenLoaded,
      tokenHasAdmin: tokenHasAdmin ?? this.tokenHasAdmin,
      tokenRoles: tokenRoles ?? this.tokenRoles,
      tokenPrimaryRole: clearTokenPrimaryRole
          ? null
          : (tokenPrimaryRole ?? this.tokenPrimaryRole),
      profileLoaded: profileLoaded ?? this.profileLoaded,
      profileHasAdmin: profileHasAdmin ?? this.profileHasAdmin,
      profileRoles: profileRoles ?? this.profileRoles,
      profilePrimaryRole: clearProfilePrimaryRole
          ? null
          : (profilePrimaryRole ?? this.profilePrimaryRole),
      adminDocLoaded: adminDocLoaded ?? this.adminDocLoaded,
      adminDocHasAdmin: adminDocHasAdmin ?? this.adminDocHasAdmin,
      serverCheckAttempted: serverCheckAttempted ?? this.serverCheckAttempted,
      serverCheckSucceeded: serverCheckSucceeded ?? this.serverCheckSucceeded,
      serverIsAdmin:
          clearServerIsAdmin ? null : (serverIsAdmin ?? this.serverIsAdmin),
      serverSource:
          clearServerSource ? null : (serverSource ?? this.serverSource),
      serverErrorCode: clearServerErrorCode
          ? null
          : (serverErrorCode ?? this.serverErrorCode),
      serverErrorMessage: clearServerErrorMessage
          ? null
          : (serverErrorMessage ?? this.serverErrorMessage),
      serverCheckedAt: clearServerCheckedAt
          ? null
          : (serverCheckedAt ?? this.serverCheckedAt),
      serverDebug: serverDebug ?? this.serverDebug,
      effectiveIsAdmin: effectiveIsAdmin ?? this.effectiveIsAdmin,
      sourceOfTruth: sourceOfTruth ?? this.sourceOfTruth,
      lastStage: lastStage ?? this.lastStage,
      debugSteps: debugSteps ?? this.debugSteps,
    );
  }
}