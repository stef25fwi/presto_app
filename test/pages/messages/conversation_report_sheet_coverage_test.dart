import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/models/marketplace_enums.dart';
import 'package:presto_app/models/marketplace_report.dart';
import 'package:presto_app/pages/messages/conversation_report_sheet.dart';
import 'package:presto_app/services/marketplace_human_verification.dart';

Widget _harness(Future<void> Function(BuildContext context) action) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => action(context),
          child: const Text('Signaler'),
        ),
      ),
    ),
  );
}

void main() {
  test('traduit tous les motifs de signalement', () {
    expect(messageReportReasonLabel(MessageReportReasonCode.spam), 'Spam');
    expect(
      messageReportReasonLabel(MessageReportReasonCode.fraud),
      'Fraude / arnaque',
    );
    expect(
      messageReportReasonLabel(MessageReportReasonCode.harassment),
      'Harcèlement',
    );
    expect(
      messageReportReasonLabel(MessageReportReasonCode.inappropriate),
      'Contenu inapproprié',
    );
    expect(
      messageReportReasonLabel(MessageReportReasonCode.other),
      'Autre motif',
    );
  });

  testWidgets('affiche les motifs puis confirme un signalement réussi', (
    tester,
  ) async {
    ConversationReportDraft? submittedDraft;
    String? submittedToken;

    await tester.pumpWidget(
      _harness(
        (context) => showConversationReportSheet(
          context,
          conversationId: 'conversation-success',
          verificationTokenProvider: (action) async {
            expect(
              action,
              MarketplaceHumanVerificationAction.messageReport,
            );
            return 'recaptcha-token';
          },
          reportSubmitter: (draft, {recaptchaToken}) async {
            submittedDraft = draft;
            submittedToken = recaptchaToken;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Signaler'));
    await tester.pumpAndSettle();

    expect(find.text('Signaler cette conversation'), findsOneWidget);
    expect(find.text('Spam'), findsOneWidget);
    expect(find.text('Fraude / arnaque'), findsOneWidget);
    expect(find.text('Harcèlement'), findsOneWidget);
    expect(find.text('Contenu inapproprié'), findsOneWidget);
    expect(find.text('Autre motif'), findsOneWidget);
    expect(find.byIcon(Icons.flag_outlined), findsNWidgets(5));

    await tester.tap(find.text('Spam'));
    await tester.pumpAndSettle();

    expect(submittedDraft, isNotNull);
    expect(submittedDraft!.conversationId, 'conversation-success');
    expect(submittedDraft!.reasonCode, MessageReportReasonCode.spam);
    expect(submittedDraft!.reasonText, isNull);
    expect(submittedToken, 'recaptcha-token');
    expect(
      find.text('Signalement envoyé. Merci pour votre retour.'),
      findsOneWidget,
    );
  });

  testWidgets('normalise le motif libre et affiche le refus serveur', (
    tester,
  ) async {
    ConversationReportDraft? submittedDraft;

    await tester.pumpWidget(
      _harness(
        (context) => showConversationReportSheet(
          context,
          conversationId: 'conversation-other',
          reasonPicker: (_) async => MessageReportReasonCode.other,
          reasonTextPicker: (_) async => '  comportement inquiétant  ',
          verificationTokenProvider: (_) async => null,
          reportSubmitter: (draft, {recaptchaToken}) async {
            submittedDraft = draft;
            expect(recaptchaToken, isNull);
            return false;
          },
        ),
      ),
    );

    await tester.tap(find.text('Signaler'));
    await tester.pumpAndSettle();

    expect(submittedDraft, isNotNull);
    expect(submittedDraft!.conversationId, 'conversation-other');
    expect(submittedDraft!.reasonCode, MessageReportReasonCode.other);
    expect(submittedDraft!.reasonText, 'comportement inquiétant');
    expect(
      find.text('Le signalement n\'a pas pu être envoyé.'),
      findsOneWidget,
    );
  });

  testWidgets('convertit un motif libre vide en valeur nulle', (
    tester,
  ) async {
    ConversationReportDraft? submittedDraft;

    await tester.pumpWidget(
      _harness(
        (context) => showConversationReportSheet(
          context,
          conversationId: 'conversation-empty-other',
          reasonPicker: (_) async => MessageReportReasonCode.other,
          reasonTextPicker: (_) async => '   ',
          verificationTokenProvider: (_) async => 'token',
          reportSubmitter: (draft, {recaptchaToken}) async {
            submittedDraft = draft;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Signaler'));
    await tester.pumpAndSettle();

    expect(submittedDraft?.reasonText, isNull);
  });

  testWidgets('affiche une erreur quand le dépôt échoue', (tester) async {
    await tester.pumpWidget(
      _harness(
        (context) => showConversationReportSheet(
          context,
          conversationId: 'conversation-error',
          reasonPicker: (_) async => MessageReportReasonCode.fraud,
          verificationTokenProvider: (_) async => 'token',
          reportSubmitter: (draft, {recaptchaToken}) async {
            throw StateError('backend indisponible');
          },
        ),
      ),
    );

    await tester.tap(find.text('Signaler'));
    await tester.pumpAndSettle();

    expect(find.text('Erreur lors du signalement.'), findsOneWidget);
  });

  testWidgets('annule sans vérifier ni envoyer', (tester) async {
    var verificationCalled = false;
    var submitCalled = false;

    await tester.pumpWidget(
      _harness(
        (context) => showConversationReportSheet(
          context,
          conversationId: 'conversation-cancelled',
          reasonPicker: (_) async => null,
          verificationTokenProvider: (_) async {
            verificationCalled = true;
            return 'unused';
          },
          reportSubmitter: (draft, {recaptchaToken}) async {
            submitCalled = true;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Signaler'));
    await tester.pumpAndSettle();

    expect(verificationCalled, isFalse);
    expect(submitCalled, isFalse);
  });

  testWidgets('abandonne quand le contexte disparaît après le choix', (
    tester,
  ) async {
    final reasonCompleter = Completer<MessageReportReasonCode?>();
    var submitCalled = false;

    await tester.pumpWidget(
      _harness(
        (context) => showConversationReportSheet(
          context,
          conversationId: 'conversation-unmounted',
          reasonPicker: (_) => reasonCompleter.future,
          reportSubmitter: (draft, {recaptchaToken}) async {
            submitCalled = true;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('Signaler'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    reasonCompleter.complete(MessageReportReasonCode.spam);
    await tester.pump();

    expect(submitCalled, isFalse);
  });
}
