import 'package:flutter/material.dart';

import 'presto_design_tokens.dart';

/// États partagés du design system : chargement, vide, erreur et succès.
///
/// Avant leur existence, chaque écran improvisait sa propre mise en page, son
/// propre vocabulaire et, surtout, sa propre sémantique — le plus souvent
/// aucune. Un lecteur d’écran ne recevait donc rien lorsqu’une liste passait
/// de « chargement » à « aucun résultat ».
///
/// Chaque état ci-dessous est une région dynamique annoncée, tient sur 320 px
/// et supporte un texte agrandi à 200 % sans perdre son action.

/// Sémantique commune à tous les états.
///
/// `liveRegion` demande au lecteur d’écran d’annoncer le changement sans que
/// l’utilisateur ait à explorer la page.
class _PrestoStateAnnouncement extends StatelessWidget {
  const _PrestoStateAnnouncement({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(child: child),
    );
  }
}

/// Ossature visuelle partagée : icône ou indicateur, titre, message, action.
class _PrestoStateLayout extends StatelessWidget {
  const _PrestoStateLayout({
    required this.leading,
    required this.title,
    this.message,
    this.action,
  });

  final Widget leading;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PrestoSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            leading,
            const SizedBox(height: PrestoSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: PrestoColors.textPrimary,
              ),
            ),
            if (message != null) ...<Widget>[
              const SizedBox(height: PrestoSpacing.xs),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: PrestoColors.textSecondary,
                ),
              ),
            ],
            if (action != null) ...<Widget>[
              const SizedBox(height: PrestoSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Chargement en cours.
class PrestoLoadingState extends StatelessWidget {
  const PrestoLoadingState({
    super.key,
    this.title = 'Chargement en cours',
    this.message,
  });

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return _PrestoStateAnnouncement(
      label: message == null ? title : '$title. $message',
      child: _PrestoStateLayout(
        leading: const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        title: title,
        message: message,
      ),
    );
  }
}

/// Absence de contenu, sans qu’il s’agisse d’une erreur.
class PrestoEmptyState extends StatelessWidget {
  const PrestoEmptyState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final hasAction = actionLabel != null && onAction != null;
    return _PrestoStateAnnouncement(
      label: message == null ? title : '$title. $message',
      child: _PrestoStateLayout(
        leading: Icon(icon, size: 40, color: PrestoColors.textSecondary),
        title: title,
        message: message,
        action: hasAction
            ? Semantics(
                button: true,
                label: actionLabel,
                child: FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              )
            : null,
      ),
    );
  }
}

/// Échec récupérable, toujours accompagné d’une action de reprise.
class PrestoErrorState extends StatelessWidget {
  const PrestoErrorState({
    super.key,
    this.title = 'Une erreur est survenue',
    this.message,
    this.retryLabel = 'Réessayer',
    this.onRetry,
  });

  final String title;
  final String? message;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _PrestoStateAnnouncement(
      label: message == null ? title : '$title. $message',
      child: _PrestoStateLayout(
        leading: const Icon(
          Icons.error_outline,
          size: 40,
          color: PrestoColors.danger,
        ),
        title: title,
        message: message,
        action: onRetry == null
            ? null
            : Semantics(
                button: true,
                label: retryLabel,
                child: FilledButton(
                  onPressed: onRetry,
                  child: Text(retryLabel),
                ),
              ),
      ),
    );
  }
}

/// Opération réussie.
class PrestoSuccessState extends StatelessWidget {
  const PrestoSuccessState({
    super.key,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final hasAction = actionLabel != null && onAction != null;
    return _PrestoStateAnnouncement(
      label: message == null ? title : '$title. $message',
      child: _PrestoStateLayout(
        leading: const Icon(
          Icons.check_circle_outline,
          size: 40,
          color: PrestoColors.success,
        ),
        title: title,
        message: message,
        action: hasAction
            ? Semantics(
                button: true,
                label: actionLabel,
                child: FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              )
            : null,
      ),
    );
  }
}
