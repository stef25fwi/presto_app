# 🐛 Correction bouton IA — page "Je publie une offre"

## 🎯 Objectif

Corriger trois bugs dans le bouton IA de la page `publish_offer_page.dart` :

1. **Bug critique (mobile)** : l'UI affiche "Enregistrement en cours" même quand le
   micro a échoué à démarrer
2. **Bug UX** : aucun spinner sur le bouton pendant l'analyse IA
3. **Bug UX** : aucun message utilisateur quand App Check bloque le bouton

---

## 📋 Changements requis

### Correction 1 — `_startMic()` : retour anticipé après échec du recorder (mobile)

**Fichier :** `lib/pages/publish_offer_page.dart`

**Problème :** Le bloc `catch` (lignes 2623–2630) ne contient pas de `return`. Le
code continue vers le `setState(() { _isListening = true; })` à la ligne 2632,
même quand `_recorder.start()` a levé une exception. L'UI affiche alors le bouton
rouge "Arrêter" et le badge "Enregistrement en cours" alors que rien n'est
enregistré. Si l'utilisateur appuie ensuite sur "Arrêter", `_stopMic()` tente
de lire un fichier audio qui n'existe pas.

**Code actuel (ligne 2623–2630) :**

```dart
    } catch (e) {
      debugPrint('Recorder start error: $e');
      _appendPublishAiTrace(
        'start_mic',
        _formatMicroIaRuntimeError(e),
        level: PublishAiTraceLevel.error,
      );
    }
```

**Code corrigé :**

```dart
    } catch (e) {
      debugPrint('Recorder start error: $e');
      _appendPublishAiTrace(
        'start_mic',
        _formatMicroIaRuntimeError(e),
        level: PublishAiTraceLevel.error,
      );
      return;
    }
```

> Ajouter `return;` **à la fin** du bloc catch, juste avant l'accolade fermante
> de ligne 2630, pour que l'exécution s'arrête en cas d'erreur et n'atteigne
> jamais le `setState(() { _isListening = true; })` à la ligne 2632.

---

### Correction 2 — `PremiumAiButton` : afficher le spinner pendant `_isAnalyzing`

**Fichier :** `lib/pages/publish_offer_page.dart`

**Problème :** Quand `_isAnalyzing = true` (analyse IA en cours après l'arrêt du
micro), le bouton est uniquement désactivé via `onPressed: null` sans aucun retour
visuel. L'utilisateur ne sait pas que l'IA travaille.

**Code actuel (lignes 3719–3725) :**

```dart
                        PremiumAiButton(
                          onPressed:
                              _isAnalyzing || signedInUser == null
                                  ? null
                                  : _startMic,
                          label: 'Décrire mon besoin (IA)',
                        ),
```

**Code corrigé :**

```dart
                        PremiumAiButton(
                          onPressed:
                              _isAnalyzing || signedInUser == null
                                  ? null
                                  : _startMic,
                          isLoading: _isAnalyzing,
                          label: 'Décrire mon besoin (IA)',
                        ),
```

> Ajouter le paramètre `isLoading: _isAnalyzing` pour que le widget
> `PremiumAiButton` (qui supporte déjà ce paramètre dans son constructeur)
> affiche un `CircularProgressIndicator` blanc pendant toute la durée de
> l'analyse.

---

### Correction 3 — `_ensureAppCheckReady()` : informer l'utilisateur en cas d'échec

**Fichier :** `lib/pages/publish_offer_page.dart`

**Problème :** La méthode déclare un paramètre `showBlockingMessage = true` (ligne
153) mais ne l'utilise jamais. Quand App Check n'est pas prêt, elle retourne
silencieusement `false` avec uniquement un `debugPrint`. L'utilisateur voit le
bouton IA ne pas réagir, sans aucune explication.

**Code actuel (lignes 151–168) :**

```dart
  Future<bool> _ensureAppCheckReady({
    required String flow,
    bool showBlockingMessage = true,
  }) async {
    if (!_useCloudStt) return true;

    if (!appCheckActivationAttempted || appCheckActivationSucceeded) {
      _appendPublishAiTrace(
        'appcheck',
        'App Check OK pour $flow',
        level: PublishAiTraceLevel.success,
      );
      return true;
    }

    debugPrint('[AppCheck] non prêt pour $flow');
    return false;
  }
```

**Code corrigé :**

```dart
  Future<bool> _ensureAppCheckReady({
    required String flow,
    bool showBlockingMessage = true,
  }) async {
    if (!_useCloudStt) return true;

    if (!appCheckActivationAttempted || appCheckActivationSucceeded) {
      _appendPublishAiTrace(
        'appcheck',
        'App Check OK pour $flow',
        level: PublishAiTraceLevel.success,
      );
      return true;
    }

    debugPrint('[AppCheck] non prêt pour $flow');
    if (showBlockingMessage && mounted) {
      showSuccessSnackBar(
        context,
        'Sécurité non prête. Réessayez dans quelques secondes.',
      );
    }
    return false;
  }
```

> Ajouter le bloc `if (showBlockingMessage && mounted)` avant le `return false`
> pour afficher un `SnackBar` explicatif quand App Check bloque le flux IA.
> La vérification `mounted` est indispensable car la méthode est `async`.

---

## ✅ Résultat attendu

Après ces trois corrections :

1. **Mobile** : si le micro échoue à démarrer, le bouton bleu reste affiché (pas
   de bascule vers l'état "Arrêter"), un message d'erreur s'affiche via la trace
   IA, et le formulaire reste utilisable.

2. **Analyse IA** : pendant toute la durée de l'analyse (après l'arrêt du micro
   ou après le tap du bouton ✨ dans le champ description), le bouton bleu affiche
   un `CircularProgressIndicator` blanc, indiquant clairement à l'utilisateur que
   l'IA travaille.

3. **App Check** : si la sécurité Firebase App Check n'est pas encore prête et
   que l'utilisateur appuie sur le bouton IA, un `SnackBar` lisible s'affiche :
   _"Sécurité non prête. Réessayez dans quelques secondes."_

---

## 🧪 Tests recommandés

### Test 1 — Échec du recorder mobile

1. Sur un appareil Android ou iOS, révoquer la permission microphone
2. Aller dans "Je publie une offre"
3. Appuyer sur le bouton bleu "Décrire mon besoin (IA)"
4. **Attendu** : snackbar "Permission micro requise" → le bouton bleu reste
   affiché, aucun bouton rouge "Arrêter" ne s'affiche

### Test 2 — Spinner pendant l'analyse

1. Lancer l'application (web ou mobile)
2. Aller dans "Je publie une offre"
3. Appuyer sur le bouton IA, parler 3–5 secondes, appuyer sur "Arrêter"
4. **Attendu** : pendant la phase d'analyse (3–6 s), le bouton bleu affiche un
   spinner blanc centré à la place de l'icône ✨ et du texte

### Test 3 — Message App Check

1. Simuler un App Check non prêt : dans `_ensureAppCheckReady`, forcer
   `appCheckActivationAttempted = true` et `appCheckActivationSucceeded = false`
2. Appuyer sur le bouton IA
3. **Attendu** : snackbar "Sécurité non prête. Réessayez dans quelques secondes."

### Test de non-régression

```bash
flutter analyze lib/pages/publish_offer_page.dart lib/widgets/premium_ai_button.dart
flutter build web --release
```

Les deux commandes doivent se terminer sans erreur.

---

## 📁 Fichiers à modifier

| Fichier | Modifications |
|---|---|
| `lib/pages/publish_offer_page.dart` | 3 corrections (lignes 2630, 3722–3724, 166–168) |
| `lib/widgets/premium_ai_button.dart` | Aucune modification requise (le widget supporte déjà `isLoading`) |
