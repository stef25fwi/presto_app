// Règles de diagnostic de déploiement Firebase affichées dans la bannière d'état.
//
// Fragment de la bibliothèque `admin_space_page.dart` : le découpage
// réduit la taille des fichiers sans modifier la visibilité des types.
part of '../admin_space_page.dart';

class _FirebaseDeployDiagnosticRule {
  final String title;
  final IconData icon;
  final Color color;
  final String summary;
  final String action;
  final List<String> needles;

  const _FirebaseDeployDiagnosticRule({
    required this.title,
    required this.icon,
    required this.color,
    required this.summary,
    required this.action,
    required this.needles,
  });
}

const String _kFirestoreRulesDeployCommand =
    'firebase deploy --project presto-app-74abe --only firestore:rules';

const List<_FirebaseDeployDiagnosticRule> _kFirebaseDeployDiagnosticRules = [
  _FirebaseDeployDiagnosticRule(
    title: 'Authentification Firebase CLI',
    icon: Icons.login_rounded,
    color: Color(0xFF1A73E8),
    summary: 'Le terminal n’est plus authentifié ou la session CLI a expiré.',
    action:
        'Relance firebase login, vérifie le compte actif puis réessaie le déploiement.',
    needles: [
      'firebase login',
      'authentication error',
      'not logged in',
      'reauth',
      'login required',
    ],
  ),
  _FirebaseDeployDiagnosticRule(
    title: 'Permissions projet insuffisantes',
    icon: Icons.admin_panel_settings_rounded,
    color: Color(0xFFD93025),
    summary:
        'Le compte connecté n’a pas les droits nécessaires sur le projet Firebase.',
    action:
        'Vérifie l’owner du projet presto-app-74abe, les rôles IAM et le compte Google utilisé par la CLI.',
    needles: [
      'permission denied',
      'permission-denied',
      'insufficient permissions',
      'caller does not have permission',
      'http error: 403',
    ],
  ),
  _FirebaseDeployDiagnosticRule(
    title: 'Projet ou configuration Firebase invalide',
    icon: Icons.folder_off_rounded,
    color: Color(0xFFF29900),
    summary:
        'La CLI ne retrouve pas le projet, firebase.json ou la cible attendue.',
    action:
        'Vérifie le dossier courant, le project id, firebase.json et le chemin vers firestore.rules.',
    needles: [
      'failed to get firebase project',
      'project not found',
      'no currently active project',
      'firebase.json',
      'firestore.rules',
      'not in a firebase app directory',
    ],
  ),
  _FirebaseDeployDiagnosticRule(
    title: 'Erreur de syntaxe ou compilation des rules',
    icon: Icons.rule_folder_rounded,
    color: Color(0xFF8E24AA),
    summary:
        'Le fichier firestore.rules ne compile pas ou contient une règle invalide.',
    action:
        'Relis firestore.rules, corrige la ligne signalée puis relance uniquement les rules.',
    needles: [
      'error parsing firestore.rules',
      'compilation errors',
      'syntax error',
      'invalid rules',
      'ruleset',
    ],
  ),
  _FirebaseDeployDiagnosticRule(
    title: 'Réseau ou service Google indisponible',
    icon: Icons.cloud_off_rounded,
    color: Color(0xFF00897B),
    summary:
        'Le poste n’a pas réussi à joindre l’API Firebase ou Google Cloud.',
    action:
        'Teste la connectivité, relance plus tard si les API sont dégradées, puis réessaie le deploy.',
    needles: [
      'failed host lookup',
      'socketexception',
      'network error',
      'econnreset',
      'service unavailable',
      'etimedout',
      'deadline-exceeded',
    ],
  ),
  _FirebaseDeployDiagnosticRule(
    title: 'Quota, billing ou API Google Cloud',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF6D4C41),
    summary:
        'Le projet n’a pas accès à la ressource requise ou a atteint une limite.',
    action:
        'Contrôle billing, quotas, APIs activées et l’état du projet dans Google Cloud Console.',
    needles: [
      'quota',
      'billing',
      'resource exhausted',
      'api has not been used',
      'enable it by visiting',
    ],
  ),
];
