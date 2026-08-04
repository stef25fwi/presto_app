// Écrans d'administration audio et de diffusion de notification.
//
// Fragment de la bibliothèque `admin_space_page.dart` : le découpage
// réduit la taille des fichiers sans modifier la visibilité des types.
part of '../admin_space_page.dart';

class _AudioPopupAdminPage extends StatelessWidget {
  const _AudioPopupAdminPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleSpacing: 16,
        title: const Text(
          'Audio popup paiement',
          style: kPrestoAppBarTitleStyle,
        ),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: PaymentInfoAudioAdminSection(),
        ),
      ),
    );
  }
}

enum _NotifTestTarget { me, all }

class _BroadcastNotificationAdminPage extends StatefulWidget {
  const _BroadcastNotificationAdminPage();

  @override
  State<_BroadcastNotificationAdminPage> createState() =>
      _BroadcastNotificationAdminPageState();
}

class _BroadcastNotificationAdminPageState
    extends State<_BroadcastNotificationAdminPage> {
  static const Color prestoOrange = Color(0xFFFF6600);

  final AdminBroadcastService _service = AdminBroadcastService();
  final TextEditingController _titleController = TextEditingController(
    text: 'Notification test',
  );
  final TextEditingController _bodyController = TextEditingController(
    text: 'Ceci est une notification test envoyée à tous les utilisateurs.',
  );

  _NotifTestTarget _target = _NotifTestTarget.me;
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSend() async {
    if (_sending) return;

    if (_target == _NotifTestTarget.all) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Envoyer à TOUS les utilisateurs ?'),
          content: const Text(
            'Cette notification push sera envoyée à tous les utilisateurs '
            'possédant un appareil enregistré. Cette action est irréversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: prestoOrange),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Envoyer à tous'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _sending = true);
    try {
      if (_target == _NotifTestTarget.me) {
        await _runSelfTest();
      } else {
        await _runBroadcast();
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _runBroadcast() async {
    try {
      final result = await _service.sendTestNotificationToAllUsers(
        title: _titleController.text,
        body: _bodyController.text,
      );
      if (!mounted) return;
      if (result.tokenCount == 0) {
        showErrorSnackBar(
          context,
          'Aucun appareil avec notifications activées '
          '(0 sur ${result.totalUsers} utilisateurs). '
          'Les utilisateurs doivent activer les notifications pour recevoir un push.',
        );
      } else {
        showSuccessSnackBar(
          context,
          'Envoyé : ${result.successCount}/${result.tokenCount} appareils '
          '— ${result.userCount} utilisateur(s) avec notifs activées '
          'sur ${result.totalUsers} au total.',
        );
      }
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = error.code == 'permission-denied'
          ? 'Accès admin requis.'
          : (error.message ?? 'Erreur lors de l’envoi.');
      showErrorSnackBar(context, message);
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Erreur lors de l’envoi : $error');
    }
  }

  Future<void> _runSelfTest() async {
    try {
      final notificationService = NotificationService();

      var registration = await notificationService.ensureDeviceRegistered();

      if (registration == DeviceRegistrationResult.permissionMissing) {
        final granted = await notificationService.requestPushPermission();
        if (!granted) {
          if (!mounted) return;
          showErrorSnackBar(
            context,
            notificationService.pushActivationFailureMessage(),
          );
          return;
        }
        registration = await notificationService.ensureDeviceRegistered();
      }

      if (registration == DeviceRegistrationResult.noToken ||
          registration == DeviceRegistrationResult.registrationFailed) {
        // Retry court: certains navigateurs délivrent le token après un second
        // passage (service worker / FCM web warmup).
        await Future<void>.delayed(const Duration(milliseconds: 350));
        registration = await notificationService.ensureDeviceRegistered();
      }

      if (registration != DeviceRegistrationResult.registered) {
        if (!mounted) return;
        showErrorSnackBar(context, _registrationIssueMessage(registration));
        return;
      }

      final count = await notificationService.sendSelfTestNotification();
      if (!mounted) return;
      showSuccessSnackBar(
        context,
        'Notification test envoyée à $count appareil(s). Verrouille ton écran : '
        'tu devrais la voir dans quelques secondes.',
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = error.code == 'failed-precondition'
          ? 'Aucun appareil enregistré. Active les notifications puis recharge la page et réessaie.'
          : (error.message ?? 'Envoi du test impossible.');
      showErrorSnackBar(context, message);
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Envoi du test impossible : $error');
    }
  }

  String _registrationIssueMessage(DeviceRegistrationResult result) {
    switch (result) {
      case DeviceRegistrationResult.permissionMissing:
        return 'Active d’abord les notifications dans Mon compte.';
      case DeviceRegistrationResult.noToken:
        return 'Impossible d’obtenir un jeton de notification sur cet appareil. '
            'Sur le web, recharge la page puis réessaie.';
      case DeviceRegistrationResult.registrationFailed:
        return 'Échec de l’enregistrement de l’appareil. Réessaie.';
      case DeviceRegistrationResult.registered:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A73E8),
        foregroundColor: Colors.white,
        elevation: 0.5,
        titleSpacing: 16,
        title: const Text('Notification test', style: kPrestoAppBarTitleStyle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_NotifTestTarget>(
                segments: const [
                  ButtonSegment(
                    value: _NotifTestTarget.me,
                    label: Text('À moi'),
                    icon: Icon(Icons.person_outline),
                  ),
                  ButtonSegment(
                    value: _NotifTestTarget.all,
                    label: Text('À tous'),
                    icon: Icon(Icons.groups_outlined),
                  ),
                ],
                selected: {_target},
                onSelectionChanged: _sending
                    ? null
                    : (selection) => setState(() => _target = selection.first),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: const Color(0xFFFFF3EA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _target == _NotifTestTarget.me
                            ? Icons.send_to_mobile_rounded
                            : Icons.campaign_rounded,
                        color: prestoOrange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _target == _NotifTestTarget.me
                              ? 'Envoie une notification test sur TES appareils '
                                  'uniquement, pour vérifier la réception (écran '
                                  'verrouillé compris).'
                              : 'Envoie immédiatement la notification à TOUS les '
                                  'utilisateurs ayant un appareil enregistré. '
                                  'À utiliser avec précaution.',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_target == _NotifTestTarget.all) ...[
                TextField(
                  controller: _titleController,
                  maxLength: 120,
                  enabled: !_sending,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bodyController,
                  maxLength: 500,
                  maxLines: 4,
                  enabled: !_sending,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: prestoOrange,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _sending ? null : _confirmAndSend,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _sending
                      ? 'Envoi en cours...'
                      : _target == _NotifTestTarget.me
                          ? 'Envoyer sur mes appareils'
                          : 'Envoyer à tous les utilisateurs',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
