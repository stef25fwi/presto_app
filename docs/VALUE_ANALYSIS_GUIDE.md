# Analyse de Valeur - Guide Complet

## Vue d'ensemble

L'**Analyse de Valeur** est une fonctionnalité qui calcule la valeur totale d'une annonce sur le marché en considérant trois éléments clés:

1. **Valeur avec 1000 utilisateurs** - Valeur basée sur la demande du marché et l'engagement des utilisateurs
2. **Valeur de reproduction** - Coût estimé pour reproduire/recreer l'article ou le service
3. **Valeur de revente** - Valeur potentielle lors d'une revente future

## Composants Techniques

### Modèles de Données

#### `ValueAnalysis` 
La classe principale représentant une analyse de valeur complète:

```dart
final ValueAnalysis analysis = ValueAnalysis(
  userBaseValue: 150.0,        // Valeur avec 1000 utilisateurs
  reproductionValue: 400.0,    // Coût de reproduction
  resaleValue: 350.0,          // Valeur de revente
  totalValue: 350.0,           // Valeur totale (somme pondérée)
  breakdown: breakdown,        // Répartition des pourcentages
  confidenceScore: 75,         // Score de fiabilité (0-100)
  analyzedAt: DateTime.now(),  // Date de l'analyse
  factors: [/* ... */],        // Facteurs influençant la valeur
);
```

#### `ValueAnalysisParams`
Paramètres d'entrée pour le calcul:

```dart
final params = ValueAnalysisParams(
  basePrice: 500.0,                    // Prix de base
  activeUsers: 1000,                   // Utilisateurs actifs
  viewCount: 75,                       // Nombre de vues
  favoriteCount: 12,                   // Nombre de favoris
  itemAgeDays: 5,                      // Âge de l'annonce (jours)
  marketDemandMultiplier: 1.0,         // Multiplicateur de demande
  itemCondition: 'like-new',           // État: new, like-new, good, fair, poor
  category: 'electronics',             // Catégorie d'article
  isPremium: true,                     // Annonce premium?
  priceHistory: [400, 450, 500],       // Historique de prix (optionnel)
);
```

### Service Principal: `ValueAnalysisService`

#### Calcul de la Valeur avec 1000 Utilisateurs

```dart
double userBaseValue = ValueAnalysisService._calculateUserBaseValue(params);
```

**Formule:**
```
userBaseValue = (viewValue + engagementValue) × premiumMultiplier × marketDemandMultiplier

où:
- viewValue = viewCount × 0.5 × (activeUsers / 1000)
- engagementValue = favoriteCount × 2.0 × (activeUsers / 1000)
- premiumMultiplier = isPremium ? 1.2 : 1.0
```

**Facteurs d'influence:**
- Nombre de vues (chaque vue = 0.5 point de valeur)
- Nombre de favoris (chaque favori = 2.0 points de valeur)
- Ratio d'utilisateurs actifs par rapport à 1000
- Statut premium (bonus 20%)
- Multiplicateur de demande marché

#### Calcul de la Valeur de Reproduction

```dart
double reproductionValue = ValueAnalysisService._calculateReproductionValue(params);
```

**Formule:**
```
reproductionValue = basePrice × reproductionRatio × conditionMultiplier × ageMultiplier

où:
- reproductionRatio varie par catégorie:
  * Services/Professionnel: 1.2 (coûte plus à reproduire)
  * General: 0.8
  * Digital/Software: 0.3 (moins cher à reproduire)
- conditionMultiplier: new=1.0, like-new=0.95, good=0.8, fair=0.6, poor=0.4
- ageMultiplier = 1.0 - (0.001 × itemAgeDays), min 0.3
```

**Utilité:** 
Estime le coût pour retrouver/recreer un article similaire de même qualité.

#### Calcul de la Valeur de Revente

```dart
double resaleValue = ValueAnalysisService._calculateResaleValue(params);
```

**Formule:**
```
resaleValue = basePrice × retentionRate × conditionMultiplier × ageMultiplier × (1 + demandBoost) × premiumMultiplier

où:
- retentionRate par catégorie:
  * Jewelry: 0.70 (très bonne retention)
  * Tools: 0.65
  * Sports: 0.55
  * Vehicles/Electronics/General: 0.50
  * Furniture: 0.50
  * Clothing: 0.30
  * Books: 0.25
- demandBoost = (marketDemandMultiplier - 1.0) × 0.5
- premiumMultiplier = isPremium ? 1.15 : 1.0
```

**Utilité:**
Prédit la valeur potentielle lors d'une revente, considérant la dépréciation naturelle.

### Calcul de la Valeur Totale

La valeur totale est une **somme pondérée** des trois composantes:

```
totalValue = (userBaseValue × w1) + (reproductionValue × w2) + (resaleValue × w3)

Poids par défaut:
- w1 (userBase) = 30% ou 40% (si article < 7 jours)
- w2 (reproduction) = 35%
- w3 (resale) = 35% ou 45% (si article > 90 jours)
```

**Logique d'ajustement:**
- Les **nouveaux articles** (< 7 jours) privilégient la valeur utilisateur
- Les **articles anciens** (> 90 jours) privilégient la valeur de revente
- Les **articles moyens** maintiennent l'équilibre

### Facteurs Influençant la Valeur

Le service extrait automatiquement les facteurs clés:

```dart
List<ValueFactor> factors = [
  ValueFactor(
    name: 'High Popularity',
    impact: 75.0,
    description: 'Strong viewer interest indicates good market demand',
    contributionPercentage: 15,
  ),
  ValueFactor(
    name: 'Excellent Condition',
    impact: 50.0,
    description: 'Like-new condition supports higher valuation',
    contributionPercentage: 10,
  ),
  ValueFactor(
    name: 'Strong Category',
    impact: 65.0,
    description: 'Jewelry items maintain value well in resale',
    contributionPercentage: 12,
  ),
  // ... plus de facteurs
];
```

### Score de Confiance

Un score (0-100) indique la fiabilité de l'analyse:

```
Score de base = 50

Bonus:
+ 15 points si viewCount > 100
+ 10 points si viewCount > 50
+ 15 points si favoriteCount > 20
+ 10 points si catégorie connue
+ 10 points si article récent (< 14 jours)
+ 5 points si annonce premium

Score final = clamp(0, 100)
```

## Exemples d'Utilisation

### Exemple 1: Article Électronique Récent et Premium

```dart
final params = ValueAnalysisParams(
  basePrice: 500.0,
  activeUsers: 1000,
  viewCount: 75,           // Bonne popularité
  favoriteCount: 12,       // Bonne engagement
  itemAgeDays: 5,          // Article récent
  itemCondition: 'like-new',
  category: 'electronics',
  isPremium: true,         // Annonce boost
);

final analysis = await ValueAnalysisService.analyzeValue(params);

// Résultats attendus:
// - userBaseValue: ~150€ (fort, article récent)
// - reproductionValue: ~380€ (80% de 500 avec condition)
// - resaleValue: ~290€ (50% retention d'electronics)
// - totalValue: ~350€ (somme pondérée avec poids utilisateur plus haut)
// - confidenceScore: ~85% (données complètes, article récent, premium)
```

### Exemple 2: Bijou Ancien avec Peu d'Engagement

```dart
final params = ValueAnalysisParams(
  basePrice: 300.0,
  activeUsers: 1000,
  viewCount: 5,            // Peu de vues
  favoriteCount: 0,        // Pas d'intérêt
  itemAgeDays: 120,        // Article ancien
  itemCondition: 'good',
  category: 'jewelry',
  isPremium: false,
);

final analysis = await ValueAnalysisService.analyzeValue(params);

// Résultats attendus:
// - userBaseValue: ~5€ (très faible)
// - reproductionValue: ~200€ (80% × 0.8 condition × 0.88 dépreciation)
// - resaleValue: ~185€ (70% retention × 0.8 × 0.88 × ajustements)
// - totalValue: ~185€ (poids resale plus élevé pour article ancien)
// - confidenceScore: ~45% (données limitées)
```

### Exemple 3: Service Professionnel

```dart
final params = ValueAnalysisParams(
  basePrice: 1000.0,
  activeUsers: 1000,
  viewCount: 150,          // Fort intérêt
  favoriteCount: 35,       // Très bonne engagement
  itemAgeDays: 10,
  itemCondition: 'new',    // Service "nouveau"
  category: 'professional',
  isPremium: true,
);

final analysis = await ValueAnalysisService.analyzeValue(params);

// Résultats attendus:
// - userBaseValue: ~420€ (élevé, bonne engagement)
// - reproductionValue: ~960€ (1.2× ratio services)
// - resaleValue: ~450€ (services moins revente, mais élevé)
// - totalValue: ~800€ (équilibre entre valeur utilisateur et reproduction)
// - confidenceScore: ~95% (données excellentes)
```

## Intégration dans l'App

### 1. Service Repository

```dart
class ListingValueRepository {
  final ValueAnalysisService _service;

  Future<ValueAnalysis> analyzeListingValue(MarketplaceListing listing, 
      {int? activeUsers}) async {
    final params = ValueAnalysisParams(
      basePrice: listing.price,
      activeUsers: activeUsers ?? 1000,
      viewCount: listing.viewCount,
      favoriteCount: listing.favoriteCount,
      itemAgeDays: _calculateDaysSinceCreated(listing.createdAt),
      category: listing.categoryId,
      isPremium: listing.isBoosted,
    );

    return ValueAnalysisService.analyzeValue(params);
  }
}
```

### 2. UI Widget

```dart
class ValueAnalysisWidget extends StatelessWidget {
  final ValueAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text('Valeur Estimée: ${ValueAnalysisService.formatCurrency(analysis.totalValue)}'),
          Text('Confiance: ${analysis.confidenceScore}%'),
          LinearProgressIndicator(value: analysis.confidence / 100),
          // Afficher les composantes
          ValueComponentRow('Utilisateurs', analysis.userBaseValue, analysis.breakdown.userBasePercentage),
          ValueComponentRow('Reproduction', analysis.reproductionValue, analysis.breakdown.reproductionPercentage),
          ValueComponentRow('Revente', analysis.resaleValue, analysis.breakdown.resalePercentage),
          // Afficher les facteurs
          ...analysis.factors.map((f) => FactorTile(factor: f)),
        ],
      ),
    );
  }
}
```

### 3. Page d'Analyse Complète

```dart
class ListingValueAnalysisPage extends StatefulWidget {
  final String listingId;

  @override
  State<ListingValueAnalysisPage> createState() =>
      _ListingValueAnalysisPageState();
}

class _ListingValueAnalysisPageState extends State<ListingValueAnalysisPage> {
  late Future<ValueAnalysis> _analysisFuture;

  @override
  void initState() {
    super.initState();
    _analysisFuture = _loadAnalysis();
  }

  Future<ValueAnalysis> _loadAnalysis() async {
    final listing = await _firestore.doc('listings/${widget.listingId}').get();
    return _valueRepository.analyzeListingValue(
      MarketplaceListing.fromFirestore(listing as DocumentSnapshot),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Analyse de Valeur')),
      body: FutureBuilder<ValueAnalysis>(
        future: _analysisFuture,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ValueAnalysisWidget(analysis: snapshot.data!);
          }
          return Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
```

## Formules Mathématiques Détaillées

### Résumé des Formules

| Composante | Formule | Facteurs |
|---|---|---|
| **User Base** | `(views × 0.5 + favs × 2.0) × (users/1000) × premium × demand` | Engagement, popularité, statut |
| **Reproduction** | `price × ratio × condition × age` | Catégorie, condition, ancienneté |
| **Resale** | `price × retention × condition × age × demand × premium` | Catégorie retention, condition, demande |
| **Total** | `UB×w1 + Rep×w2 + RS×w3` | Poids dynamiques selon âge |

### Valeurs de Retenue par Catégorie

```
Jewelry:      70%  (très bonne conservation)
Tools:        65%  (bonne conservation)
Sports:       55%  (conservation moyenne)
Electronics:  50%  (conservation moyenne)
Vehicles:     50%  (conservation moyenne)
Furniture:    50%  (conservation moyenne)
Clothing:     30%  (mauvaise conservation)
Books:        25%  (mauvaise conservation)
```

### Multiplicateurs de Condition

```
New:       1.0  (article neuf)
Like-new:  0.95 (comme neuf)
Excellent: 0.90 (excellent)
Good:      0.80 (bon)
Fair:      0.60 (moyen)
Poor:      0.40 (mauvais)
```

## Notes d'Implémentation

1. **Asynchrone:** Le calcul est asynchrone pour permettre une éventuelle requête API future
2. **Sérialisation:** Toutes les classes supportent `toMap()` et `fromMap()`
3. **Tests:** Complets avec 10+ scénarios de test
4. **Extensibilité:** Facile d'ajouter de nouvelles catégories/facteurs
5. **Localisation:** Support du formatage en euros (€)

## Cas d'Usage Futurs

- Prédiction de prix basée sur données historiques
- Recommandations de prix optimal
- Détection d'annonces survaluées/sous-valuées
- Comparaison avec articles similaires
- Historique d'évolution de valeur
