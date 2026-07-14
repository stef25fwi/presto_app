# Mesure LCOV réelle après PR #320

- Source : `c7ecd7a171b705dde3c2e3fd4820c08dba14d449`
- Workflow : `29366613691`
- Artefact : `pr-validation-c6d3c232b225406319ffd2b85d164d1cdadbc51b`

## Global

- 5 953 / 39 772 lignes = **14,97 %**
- Lignes restantes pour 100 % : **33 819**
- Fichiers présents dans LCOV : **257**

## Auth

Le périmètre Auth utilise les patterns de `quality/critical-coverage.json`.

- 499 / 1 038 lignes = **48,07 %**
- Lignes restantes pour 100 % : **539**
- Fichiers suivis : **20 / 20 = 100 %**
- Fichiers Auth absents du LCOV : **0**

## Auth par fichier

| Couverture | Couvertes/Total | Reste | Fichier | Lignes non couvertes |
|---:|---:|---:|---|---|
| 0,00 % | 0/232 | 232 | `lib/services/account_social_auth_actions.dart` | 25, 33, 39, 44, 46, 52-53, 55-58, 64-67, 74, 77-81, 88, 94-96, 100, 109, 115, 120-121, 124-125, 127-129, 135, 137-139, 144, 146-149, 152, 155-156, 160, 167, 170, 172, 175-176, 178, 180, 183-186, 188-190, 192-194, 196-200, 202-204, 207-210, 214, 219-220, 223-224, 231-232, 234-236, 239-240, 244-245, 248-249, 257-259, 261-262, 269, 275-278, 286-288, 290-291, 298-299, 302-303, 306-308, 312-314, 317-322, 325, 327-332, 334, 339, 343, 350, 353, 355, 357, 359, 362-366, 370-371, 374, 378, 382, 385, 388, 391, 394, 401-404, 407-408, 412, 415, 418, 421, 424-425, 429, 431, 433-435, 439, 447, 451-452, 454, 460, 467-468, 472, 474, 477, 479, 481, 484, 487-493, 495-498, 500-503, 505, 510-513, 517, 524-527, 529, 531-533, 535, 537, 539, 542, 547, 550-551, 553-554, 557-559, 562-566, 572, 574 |
| 0,00 % | 0/150 | 150 | `lib/services/auth_service.dart` | 19, 21, 27, 29, 31-32, 34, 41-43, 46-47, 53, 62, 64-65, 69, 71, 77-79, 81-82, 85, 87-96, 100, 105, 109, 111-112, 116, 118-122, 130, 133, 139, 142, 145, 148-150, 152, 154, 159-160, 162-163, 165-167, 171, 174-175, 178-180, 182-183, 186, 192-195, 203, 207-208, 210-211, 217, 222-223, 225-228, 231, 235-236, 238-239, 245, 250, 252-255, 257-259, 263, 266, 268-269, 271-272, 277-278, 284, 288, 290, 292, 294, 302-303, 311, 317-318, 321-323, 327-328, 330-331, 334-335, 339-340, 342, 345-346, 348, 353, 357, 360, 362, 364, 369, 373, 377-381, 384, 387-388, 390 |
| 1,01 % | 1/99 | 98 | `lib/pages/auth/register_page.dart` | 13-14, 25-26, 28-32, 34, 40, 42-47, 50-51, 53, 56-63, 66, 68-70, 73-75, 78, 82-85, 89-92, 96, 98-99, 102, 106, 110-114, 116, 118-120, 122, 142, 144-147, 157-159, 167-169, 179-181, 191-192, 199, 202-203, 210, 213-216, 220-221, 224-225, 228, 231, 234, 236-238, 256-260 |
| 82,72 % | 67/81 | 14 | `lib/pages/auth/verify_email_page.dart` | 45, 52, 81-84, 86, 128, 139-142, 209-210 |
| 0,00 % | 0/14 | 14 | `lib/services/auth_guard.dart` | 8, 10-11, 14, 16-17, 23-24, 26-27, 31-32, 34-35 |
| 85,53 % | 65/76 | 11 | `lib/features/auth/services/user_profile_service.dart` | 39, 54-55, 71, 108, 110, 134, 144-145, 206, 208 |
| 84,91 % | 45/53 | 8 | `lib/features/auth/services/auth_service.dart` | 55-56, 83, 127, 153, 160, 180, 186 |
| 76,00 % | 19/25 | 6 | `lib/pages/auth/auth_gate.dart` | 37-38, 40-42, 44 |
| 95,65 % | 44/46 | 2 | `lib/pages/auth/forgot_password_page.dart` | 51-52 |
| 91,67 % | 11/12 | 1 | `lib/features/auth/presentation/widgets/auth_error_box.dart` | 4 |
| 95,65 % | 22/23 | 1 | `lib/features/auth/validators/auth_validators.dart` | 2 |
| 50,00 % | 1/2 | 1 | `lib/pages/auth/login_page.dart` | 15 |
| 94,12 % | 16/17 | 1 | `lib/services/auth_error_mapper.dart` | 4 |
| 100,00 % | 10/10 | 0 | `lib/features/auth/presentation/widgets/auth_primary_button.dart` | - |
| 100,00 % | 25/25 | 0 | `lib/features/auth/presentation/widgets/auth_text_field.dart` | - |
| 100,00 % | 4/4 | 0 | `lib/pages/auth/auth_gate_policy.dart` | - |
| 100,00 % | 16/16 | 0 | `lib/pages/auth/reset_password_success_page.dart` | - |
| 100,00 % | 4/4 | 0 | `lib/services/auth_status_policy.dart` | - |
| 100,00 % | 33/33 | 0 | `lib/services/email_auth_error_mapper.dart` | - |
| 100,00 % | 116/116 | 0 | `lib/services/google_auth_service.dart` | - |

## Priorité issue de la mesure

1. `account_social_auth_actions.dart` : 232 lignes restantes.
2. `auth_service.dart` : 150 lignes restantes.
3. `register_page.dart` : 98 lignes restantes.
4. `verify_email_page.dart` et `auth_guard.dart` : 14 lignes restantes chacun.
5. `user_profile_service.dart` : 11 lignes restantes.
6. `features/auth/services/auth_service.dart` : 8 lignes restantes.
7. `auth_gate.dart` : 6 lignes restantes.
8. Finir les fichiers à 1 ou 2 lignes restantes.

Aucun module n’est déclaré à 100 %. Seuls les fichiers individuellement mesurés à 100 % ci-dessus peuvent être considérés comme entièrement couverts pour ce LCOV précis.