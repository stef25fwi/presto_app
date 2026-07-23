from pathlib import Path

path = Path('test/pages/messages/conversation_thread_page_interactions_test.dart')
source = path.read_text()

source = source.replace(
    "  Future<void> pumpThread(WidgetTester tester) async {\n",
    "  Future<void> pumpThread(\n    WidgetTester tester, {\n    String? initialDraftText,\n  }) async {\n",
    1,
)
source = source.replace(
    "      const MaterialApp(\n        home: ConversationThreadPage(\n",
    "      MaterialApp(\n        home: ConversationThreadPage(\n",
    1,
)
source = source.replace(
    "          currentUserId: 'thread-user',\n        ),\n",
    "          currentUserId: 'thread-user',\n          initialDraftText: initialDraftText,\n        ),\n",
    1,
)

marker = "\n  testWidgets('insère un emoji rapide puis referme la barre'"
if marker not in source:
    raise SystemExit('interaction insertion marker missing')

extra = r'''

  testWidgets('applique le brouillon initial selon les branches du contrat',
      (tester) async {
    await pumpThread(tester, initialDraftText: '  Brouillon proposé  ');
    final dynamic state = tester.state(find.byType(ConversationThreadPage));

    state.messageController.clear();
    state.didApplyInitialDraft = false;
    state.applyInitialDraftIfNeeded(false);
    await tester.pump();
    expect(state.messageController.text, 'Brouillon proposé');
    expect(state.didApplyInitialDraft, isTrue);

    state.messageController.text = 'Texte existant';
    state.didApplyInitialDraft = false;
    state.applyInitialDraftIfNeeded(false);
    expect(state.messageController.text, 'Texte existant');
    expect(state.didApplyInitialDraft, isTrue);

    state.didApplyInitialDraft = false;
    state.applyInitialDraftIfNeeded(true);
    expect(state.didApplyInitialDraft, isFalse);

    await _disposeAfterBootstrap(tester);
  });

  testWidgets('couvre les bannières et variantes du menu conversation',
      (tester) async {
    await pumpThread(tester);
    final dynamic state = tester.state(find.byType(ConversationThreadPage));

    state.setState(() {
      state.conversationBlocked = true;
      state.blockedForCurrentUser = true;
      state.blockedByAnotherParticipant = false;
      state.adminViewerState = false;
      state.archivedForCurrentUser = false;
    });
    await tester.pump();
    expect(
      find.text(
        'Vous avez bloque cette conversation. Debloquez-la pour reprendre les echanges.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    expect(find.text('Debloquer'), findsOneWidget);
    Navigator.of(tester.element(find.text('Debloquer'))).pop();
    await tester.pump();

    state.setState(() {
      state.blockedForCurrentUser = false;
      state.blockedByAnotherParticipant = true;
      state.adminViewerState = true;
    });
    await tester.pump();
    expect(
      find.text(
        'Cette conversation a ete bloquee par un participant. Un admin peut la debloquer.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    expect(find.text('Debloquer en admin'), findsOneWidget);
    Navigator.of(tester.element(find.text('Debloquer en admin'))).pop();
    await tester.pump();

    state.setState(() {
      state.conversationBlocked = false;
      state.blockedByAnotherParticipant = false;
      state.adminViewerState = false;
      state.archivedForCurrentUser = true;
    });
    await tester.pump();
    expect(
      find.text(
        'Conversation archivee pour vous. Un nouveau message la restaurera automatiquement.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    expect(find.text('Restaurer'), findsOneWidget);
    expect(find.text('Bloquer'), findsOneWidget);
    Navigator.of(tester.element(find.text('Restaurer'))).pop();
    await tester.pump();

    await _disposeAfterBootstrap(tester);
  });
'''
source = source.replace(marker, extra + marker, 1)
path.write_text(source)
