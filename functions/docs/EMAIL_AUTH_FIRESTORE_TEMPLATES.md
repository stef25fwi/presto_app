# Templates Firestore Auth Avec Logo

Ces snippets sont prets pour la collection email_template_versions dans Firestore.

Les variables suivantes sont injectees automatiquement au rendu:

- {{brandLogoUrl}}
- {{brandLogoAlt}}
- {{brandName}}
- {{brandSignature}}

Les templates auth charges depuis Firestore recoivent maintenant automatiquement le bloc logo si vous ne l'avez pas deja mis dans le HTML. Les snippets ci-dessous permettent toutefois de garder un rendu maitrise a 100 %.

## Email Verification

Template code: tpl_transactional_account_email_verification_v1

```html
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <title>Confirmez votre adresse e-mail</title>
  </head>
  <body style="margin:0;padding:24px;background:#FFF7F1;font-family:Arial,sans-serif;color:#111827;">
    <div style="max-width:640px;margin:0 auto;background:#FFFFFF;border:1px solid #E5E7EB;border-radius:18px;padding:28px;">
      <div data-presto-email-branding="true" style="padding:0 0 24px 0;">
        <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">Cliquez pour verifier votre e-mail</div>
        <img src="{{brandLogoUrl}}" alt="{{brandLogoAlt}}" width="124" style="display:block;max-width:124px;height:auto;border:0;">
      </div>
      <h1 style="margin:0 0 12px;font-size:26px;line-height:1.2;color:#111827;">Confirmez votre adresse e-mail</h1>
      <p style="margin:0 0 16px;font-size:16px;line-height:1.6;">Bonjour {{firstName}},</p>
      <p style="margin:0 0 24px;font-size:16px;line-height:1.6;">Cliquez sur le bouton ci-dessous pour verifier votre compte {{brandName}}.</p>
      <a href="{{verificationUrl}}" style="display:inline-block;background:#FF6600;color:#FFFFFF;text-decoration:none;font-weight:700;padding:14px 20px;border-radius:999px;">Verifier mon e-mail</a>
    </div>
  </body>
</html>
```

## Password Reset

Template code: tpl_transactional_account_password_forgotten_v1

```html
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <title>Reinitialiser votre mot de passe</title>
  </head>
  <body style="margin:0;padding:24px;background:#FFF7F1;font-family:Arial,sans-serif;color:#111827;">
    <div style="max-width:640px;margin:0 auto;background:#FFFFFF;border:1px solid #E5E7EB;border-radius:18px;padding:28px;">
      <div data-presto-email-branding="true" style="padding:0 0 24px 0;">
        <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">Lien valable 1 heure</div>
        <img src="{{brandLogoUrl}}" alt="{{brandLogoAlt}}" width="124" style="display:block;max-width:124px;height:auto;border:0;">
      </div>
      <h1 style="margin:0 0 12px;font-size:26px;line-height:1.2;color:#111827;">Reinitialiser votre mot de passe</h1>
      <p style="margin:0 0 16px;font-size:16px;line-height:1.6;">Bonjour {{firstName}},</p>
      <p style="margin:0 0 24px;font-size:16px;line-height:1.6;">Nous avons recu une demande de reinitialisation pour votre compte {{brandName}}.</p>
      <a href="{{resetUrl}}" style="display:inline-block;background:#1A73E8;color:#FFFFFF;text-decoration:none;font-weight:700;padding:14px 20px;border-radius:999px;">Reinitialiser mon mot de passe</a>
    </div>
  </body>
</html>
```

## Password Changed

Template code: tpl_transactional_account_password_changed_v1

```html
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <title>Votre mot de passe a ete modifie</title>
  </head>
  <body style="margin:0;padding:24px;background:#FFF7F1;font-family:Arial,sans-serif;color:#111827;">
    <div style="max-width:640px;margin:0 auto;background:#FFFFFF;border:1px solid #E5E7EB;border-radius:18px;padding:28px;">
      <div data-presto-email-branding="true" style="padding:0 0 24px 0;">
        <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">Si ce n'est pas vous, contactez le support</div>
        <img src="{{brandLogoUrl}}" alt="{{brandLogoAlt}}" width="124" style="display:block;max-width:124px;height:auto;border:0;">
      </div>
      <h1 style="margin:0 0 12px;font-size:26px;line-height:1.2;color:#111827;">Mot de passe modifie</h1>
      <p style="margin:0 0 16px;font-size:16px;line-height:1.6;">Bonjour {{firstName}},</p>
      <p style="margin:0;font-size:16px;line-height:1.6;">Votre mot de passe {{brandName}} a bien ete modifie. Si vous n'etes pas a l'origine de cette action, contactez le support sans attendre.</p>
    </div>
  </body>
</html>
```

## Suspicious Login

Template code: tpl_transactional_account_suspicious_login_v1

```html
<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <title>Connexion suspecte detectee</title>
  </head>
  <body style="margin:0;padding:24px;background:#FFF7F1;font-family:Arial,sans-serif;color:#111827;">
    <div style="max-width:640px;margin:0 auto;background:#FFFFFF;border:1px solid #E5E7EB;border-radius:18px;padding:28px;">
      <div data-presto-email-branding="true" style="padding:0 0 24px 0;">
        <div style="display:none;max-height:0;overflow:hidden;opacity:0;color:transparent;">Securisez votre compte maintenant</div>
        <img src="{{brandLogoUrl}}" alt="{{brandLogoAlt}}" width="124" style="display:block;max-width:124px;height:auto;border:0;">
      </div>
      <h1 style="margin:0 0 12px;font-size:26px;line-height:1.2;color:#111827;">Connexion suspecte detectee</h1>
      <p style="margin:0 0 16px;font-size:16px;line-height:1.6;">Bonjour {{firstName}},</p>
      <p style="margin:0 0 8px;font-size:16px;line-height:1.6;">Une connexion inhabituelle a ete detectee.</p>
      <p style="margin:0 0 4px;font-size:15px;line-height:1.6;"><strong>Appareil :</strong> {{device}}</p>
      <p style="margin:0 0 24px;font-size:15px;line-height:1.6;"><strong>IP :</strong> {{ip}}</p>
      <a href="{{secureUrl}}" style="display:inline-block;background:#FF6600;color:#FFFFFF;text-decoration:none;font-weight:700;padding:14px 20px;border-radius:999px;">Securiser mon compte</a>
    </div>
  </body>
</html>
```