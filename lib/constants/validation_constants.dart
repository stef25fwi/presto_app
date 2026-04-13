/// Constantes partagées avec le backend (functions/src/shared/constants.ts)
/// À mettre à jour en tandem avec LISTING_VALIDATION côté TS.
abstract class ListingValidation {
  static const int titleMinLength = 10;
  static const int titleMaxLength = 120;
  static const int descriptionMinLength = 30;
  static const int descriptionMaxLength = 4000;
  static const int maxMediaCount = 10;
}
