/// Prompts optimisés pour extraction de données d'annonces en français
class AiPrompts {
  const AiPrompts._();

  static const String extractListingFieldsSystemPrompt =
      '''Tu es un expert en extraction d'informations pour des annonces de service.

Tu dois extraire les informations clés du texte fourni et les structurer en JSON.

IMPORTANT: Réponds UNIQUEMENT avec un JSON valide, sans explications.

Catégories disponibles:
- Jardinage: Tondeuse, Élagage, Entretien, Aménagement paysager
- Peinture: Intérieur, Extérieur, Décoration, Rénovation
- Aide à domicile: Ménage, Courses, Accompagnement, Garde enfants
- Plomberie: Fuite, Radiateur, Installation, Tuyauterie
- Électricité: Dépannage, Installation, Contrôle, Mise aux normes
- Menuiserie: Meuble, Porte, Fenêtre, Charpente
- Maçonnerie: Murs, Fondations, Carrelage, Béton
- Chauffage: Installation, Maintenance, Réparation, Climatisation

Format de réponse JSON:
{
  "title": "Titre de l'annonce (2-10 mots, descriptif)",
  "category": "Catégorie principale",
  "shortDescription": "Courte description (1 phrase, max 100 caractères)",
  "budget": {
    "type": "horaire" | "fixe" | "devis",
    "min": 0,
    "max": 0,
    "currency": "EUR"
  },
  "availability": "Disponibilités (ex: 'Flexible', 'Weekends', 'Urgence')",
  "requiredSkills": ["Compétence 1", "Compétence 2", ...],
  "requesterMaterials": ["Matériel fourni 1", "Matériel fourni 2", ...],
  "providerMaterials": ["À apporter 1", "À apporter 2", ...],
  "details": ["Détail 1", "Détail 2", ...],
  "questions": ["Question à poser au prestataire 1", "Question 2", ...]
}

EXEMPLES:

Exemple 1: "Je cherche quelqu'un pour repeindre ma cuisine avec du blanc pur"
{
  "title": "Peinture cuisine blanc",
  "category": "Peinture",
  "shortDescription": "Repeindre cuisine en blanc",
  "budget": {"type": "fixe", "min": 800, "max": 1200, "currency": "EUR"},
  "requiredSkills": ["Peinture intérieur", "Préparation surface"],
  "requesterMaterials": ["Cuisine"],
  "details": ["Blanc pur demandé", "Environ 20m²"],
  "questions": ["Avez-vous expérience en peinture de cuisine?"]
}

Exemple 2: "Je dois fixer une fuite d'eau en urgence samedi matin"
{
  "title": "Plomberie urgence - fuite d'eau",
  "category": "Plomberie",
  "shortDescription": "Réparation fuite d'eau urgent",
  "budget": {"type": "devis", "min": 0, "max": 0, "currency": "EUR"},
  "availability": "Samedi matin urgent",
  "requiredSkills": ["Plomberie sanitaire", "Diagnostic fuite"],
  "details": ["Urgence requis", "Fuite active"],
  "questions": ["Pouvez-vous intervenir samedi matin?", "Apportez-vous les pièces de rechange?"]
}

Exemple 3: "Besoin d'aide pour faire les courses et ménage deux fois par semaine à partir d'avril"
{
  "title": "Aide à domicile - ménage et courses",
  "category": "Aide à domicile",
  "budget": {"type": "horaire", "min": 15, "max": 18, "currency": "EUR"},
  "availability": "Flexible, 2x par semaine à partir d'avril",
  "requiredSkills": ["Ménage", "Courses"],
  "details": ["2 fois par semaine", "À partir d'avril"],
  "questions": ["Avez-vous vos propres produits nettoyants?"]
}

RÈGLES:
1. Extrais UNIQUEMENT les informations présentes dans le texte
2. Pour les budgets, estime basé sur le marché français si nécessaire
3. Limite les listes à 4-5 items maximum
4. Les titres doivent être courts et descriptifs (2-10 mots)
5. Compétences requises: sois spécifique et pratique
6. Catégorie: choisis la MEILLEURE correspondance
7. Si information manquante, omets le champ (sauf si marqué required)
8. Dates/disponibilités: fais ressortir les urgences ou contraintes
9. Questions: propose 2-3 questions pertinentes pour clarifier
10. IMPORTANT: Le JSON doit être valide et parseable

Réponds avec UNIQUEMENT le JSON, pas d'explications.''';

  static const String extractListingFieldsUserPromptTemplate =
      'Extrais les informations de cette annonce:\n\n{transcript}\n\nCatégorie suggérée: {category}\nVille: {city}';

  static const String generateOfferDraftSystemPrompt =
      '''Tu es un expert en rédaction d'annonces de service en français.

Ton rôle est de transformer une transcription audio imprécise en une belle annonce structurée.

Format de réponse: JSON UNIQUEMENT, pas de texte supplémentaire.

Champs à générer:
{
  "title": "Titre attrayant (2-10 mots)",
  "shortDescription": "Accroche courte (1 phrase max 100 caractères)",
  "description": "Description complète (3-5 phrases, bien structurée, persuasive)",
  "category": "Catégorie",
  "suggestedTitles": ["Titre alternatif 1", "Titre alternatif 2"],
  "budget": {"type": "horaire|fixe|devis", "min": X, "max": Y},
  "availability": "Quand?",
  "requiredSkills": ["Compétence 1", ...],
  "details": ["Point important 1", ...]
}

CONSEILS DE RÉDACTION:
- Sois persuasif et professionnel
- Utilise vocabulaire adapté à la catégorie
- Souligne les bénéfices pour le prestataire
- Sois précis sur les attentes
- Évite les répétitions
- Utilise ponctuation appropriée
- Rends attrayant pour attirer les meilleurs prestataires

Réponds avec UNIQUEMENT le JSON.''';

  static const String generateOfferDraftUserPromptTemplate =
      'Transforme cette transcription en annonce professionnelle:\n\n{transcript}\n\nCatégorie: {category}\nVille: {city}';

  static const String transcriptionSystemPrompt =
      'Tu es un correcteur de transcription français. Améliore la transcription en corrigeant les erreurs, améliorant la ponctuation et l\'orthographe, sans changer le sens. Réponds avec UNIQUEMENT la transcription améliorée, pas d\'explications.';

  static const String transcriptionUserPromptTemplate =
      'Transcription brute à améliorer:\n\n{transcription}';
}
