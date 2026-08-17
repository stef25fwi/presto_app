import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/typography_settings.dart';
import '../constants.dart';

const _prestoBlue = Color(0xFF1A73E8);
const _prestoOrange = Color(0xFFFF6600);
const _prestoGreen = Color(0xFF0F9D58);

class AdminTypographyPage extends StatefulWidget {
  const AdminTypographyPage({super.key});

  @override
  State<AdminTypographyPage> createState() => _AdminTypographyPageState();
}

class _AdminTypographyPageState extends State<AdminTypographyPage> {
  late double _scale;
  late String _selectedFont;
  late int _weightDelta;
  late List<String> _fontList;
  late TextEditingController _searchController;
  late TextEditingController _addFontController;

  bool _isModified = false;
  bool _showAddFontDialog = false;
  String _addFontError = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _searchController = TextEditingController();
    _addFontController = TextEditingController();
  }

  void _loadSettings() {
    _scale = typographySettings.scale;
    _selectedFont = typographySettings.fontFamily;
    _weightDelta = typographySettings.fontWeightDelta;
    _fontList = List<String>.from(kAvailableFontFamilies);
  }

  void _updateIsModified() {
    setState(() {
      _isModified = _scale != typographySettings.scale ||
          _selectedFont != typographySettings.fontFamily ||
          _weightDelta != typographySettings.fontWeightDelta;
    });
  }

  bool get _isDefault =>
      _scale == 1.0 && _selectedFont == 'Inter' && _weightDelta == 0;

  void _apply() {
    typographySettings.apply(
      scale: _scale,
      fontFamily: _selectedFont,
      fontWeightDelta: _weightDelta,
    );
    _updateIsModified();
    _showSnackbar('✅ Typographie appliquée', Colors.green);
  }

  void _reset() {
    setState(() {
      _scale = 1.0;
      _selectedFont = 'Inter';
      _weightDelta = 0;
    });
    typographySettings.reset();
    _updateIsModified();
    _showSnackbar('🔄 Réinitialisation appliquée', Colors.green);
  }

  void _addNewFont() {
    final fontName = _addFontController.text.trim();

    // Validation
    if (fontName.isEmpty) {
      setState(() => _addFontError = 'Nom requis');
      return;
    }
    if (_fontList.contains(fontName)) {
      setState(() => _addFontError = 'Police déjà présente');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(fontName)) {
      setState(() =>
          _addFontError = 'Caractères valides : lettres, chiffres, tirets');
      return;
    }

    // Ajouter la police
    setState(() {
      _fontList.add(fontName);
      _addFontController.clear();
      _addFontError = '';
      _showAddFontDialog = false;
    });
    _showSnackbar('✅ Police "$fontName" ajoutée', Colors.green);
  }

  void _removeFont(String fontName) {
    if (fontName == 'Inter') {
      _showSnackbar(
          '❌ Impossible de supprimer la police par défaut', Colors.red);
      return;
    }
    if (_selectedFont == fontName) {
      setState(() => _selectedFont = 'Inter');
    }
    setState(() => _fontList.remove(fontName));
    _showSnackbar('✅ Police supprimée', Colors.orange);
  }

  void _showSnackbar(String msg, Color bgColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bgColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _weightLabel(int delta) {
    const labels = {
      -2: '−2 très léger',
      -1: '−1 léger',
      0: 'Normal',
      1: '+1 gras',
      2: '+2 très gras'
    };
    return labels[delta] ?? '$delta';
  }

  List<String> _getFilteredFonts() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _fontList;
    return _fontList.where((f) => f.toLowerCase().contains(query)).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _addFontController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '✍️  Gestion Typographie',
          style: kPrestoAppBarTitleStyle,
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        actions: [
          if (!_isDefault)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: 'Réinitialiser aux valeurs par défaut',
                child: TextButton(
                  onPressed: _reset,
                  child: const Text('Réinitialiser',
                      style: TextStyle(
                        color: _prestoBlue,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 📋 Résumé
            _buildInfoCard(),
            const SizedBox(height: 20),

            // ✅ Vérification portée globale
            _buildGlobalCoverageCard(),
            const SizedBox(height: 20),

            // 🎚️ Contrôles (Scale, Weight)
            _buildScaleControl(),
            const SizedBox(height: 16),
            _buildWeightControl(),
            const SizedBox(height: 20),

            // 🔤 Gestion des polices
            _buildFontManagement(),
            const SizedBox(height: 20),

            // 👁️ Aperçu en direct
            _buildLivePreview(),
            const SizedBox(height: 20),

            // ✅ Bouton d'application
            if (_isModified)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _apply,
                  style: FilledButton.styleFrom(
                    backgroundColor: _prestoGreen,
                  ),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Appliquer pour toute l\'application'),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_rounded, color: _prestoBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'État actuel',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildInfoPill('Police', typographySettings.fontFamily),
              _buildInfoPill(
                'Taille',
                '${(typographySettings.scale * 100).round()}%',
              ),
              _buildInfoPill(
                'Graisse',
                _weightLabel(typographySettings.fontWeightDelta),
              ),
            ],
          ),
          if (_isModified) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.pending_outlined,
                    size: 16, color: _prestoOrange),
                const SizedBox(width: 6),
                Text(
                  'Modifications en attente',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlobalCoverageCard() {
    final sameAsApplied = _scale == typographySettings.scale &&
        _selectedFont == typographySettings.fontFamily &&
        _weightDelta == typographySettings.fontWeightDelta;
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                sameAsApplied
                    ? Icons.verified_user_rounded
                    : Icons.sync_problem_rounded,
                color: sameAsApplied ? _prestoGreen : _prestoOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Portée: toute l\'application',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            sameAsApplied
                ? 'Réglages actifs globalement. Les pages utilisent déjà cette police et cette taille.'
                : 'Les réglages ci-dessous ne sont pas encore appliqués globalement. Utilisez le bouton vert pour les activer partout.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD7DEE8)),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7DEE8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _buildScaleControl() {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.zoom_in_rounded, color: _prestoBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Taille du texte',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _scale,
                  min: 0.8,
                  max: 1.4,
                  divisions: 12,
                  activeColor: _prestoBlue,
                  label: '${(_scale * 100).round()}%',
                  onChanged: (v) {
                    setState(() => _scale = v);
                    _updateIsModified();
                  },
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '${(_scale * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _prestoBlue,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '80% à 140% du texte de base',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightControl() {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_bold_rounded,
                  color: _prestoBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Épaisseur (graisse)',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _weightDelta.toDouble(),
                  min: -2,
                  max: 2,
                  divisions: 4,
                  activeColor: _prestoBlue,
                  label: _weightLabel(_weightDelta),
                  onChanged: (v) {
                    setState(() => _weightDelta = v.round());
                    _updateIsModified();
                  },
                ),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  _weightLabel(_weightDelta),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _prestoBlue,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'De très léger (−2) à très gras (+2)',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildFontManagement() {
    final filtered = _getFilteredFonts();

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.text_fields_rounded,
                  color: _prestoBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Polices disponibles',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Tooltip(
                message: 'Ajouter une nouvelle police',
                child: IconButton(
                  onPressed: () =>
                      setState(() => _showAddFontDialog = !_showAddFontDialog),
                  icon: const Icon(Icons.add_rounded, color: _prestoOrange),
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 🔍 Barre de recherche
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '🔍 Rechercher une police...',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _searchController.text.isNotEmpty
                  ? Semantics(
                      button: true,
                      label: 'Effacer la recherche',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          child: const Icon(Icons.clear_rounded, size: 18),
                        ),
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD7DEE8)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 12),
          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Aucune police trouvée',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filtered.map((font) {
                final isSelected = _selectedFont == font;
                final isDefault = font == 'Inter';

                void deleteFont() {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Supprimer la police ?'),
                      content: Text(
                        'Êtes-vous sûr de vouloir supprimer "$font" ?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Annuler'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _removeFont(font);
                          },
                          child: const Text('Supprimer',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                }

                return Tooltip(
                  message: isDefault
                      ? 'Police par défaut'
                      : 'Cliquer pour sélectionner',
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    // L'appui long ouvre une suppression pour les polices
                    // personnalisées : exposé en plus comme action discrète,
                    // l'appui long n'ayant pas d'équivalent clavier garanti.
                    customSemanticsActions: isDefault
                        ? const <CustomSemanticsAction, VoidCallback>{}
                        : <CustomSemanticsAction, VoidCallback>{
                            const CustomSemanticsAction(
                              label: 'Supprimer la police',
                            ): deleteFont,
                          },
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() => _selectedFont = font);
                      _updateIsModified();
                      _showSnackbar(
                          '✅ Police "$font" sélectionnée', Colors.blue);
                    },
                    onLongPress: !isDefault ? deleteFont : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? const Color(0xFFE8F0FE) : Colors.white,
                        border: Border.all(
                          color: isSelected
                              ? _prestoBlue
                              : const Color(0xFFD7DEE8),
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            font,
                            style: TextStyle(
                              fontFamily: font,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? _prestoBlue : Colors.black87,
                            ),
                          ),
                          if (isDefault)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: _prestoBlue,
                              ),
                            ),
                          if (!isDefault && isSelected)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.red,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                    ),
                  ),
                );
              }).toList(),
            ),

          if (_showAddFontDialog) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3EA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '➕ Ajouter une nouvelle police',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.orange.shade900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addFontController,
                    decoration: InputDecoration(
                      hintText: 'Ex: Roboto, Poppins, Playfair...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() => _addFontError = ''),
                  ),
                  if (_addFontError.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '❌ $_addFontError',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => setState(() {
                          _showAddFontDialog = false;
                          _addFontController.clear();
                          _addFontError = '';
                        }),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _addNewFont,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Ajouter'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLivePreview() {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_rounded,
                  color: _prestoBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'Aperçu en direct',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(_scale)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_selectedFont • ${(_scale * 100).round()}%${_weightDelta != 0 ? ' • Graisse ${_weightDelta > 0 ? '+' : ''}$_weightDelta' : ''}',
                    style: TextStyle(
                      fontFamily: _selectedFont,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Titre de section',
                    style: TextStyle(
                      fontFamily: _selectedFont,
                      fontSize: 18,
                      fontWeight:
                          shiftFontWeight(FontWeight.w700, _weightDelta),
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Texte courant — iliprestō facilite les connexions entre professionnels.',
                    style: TextStyle(
                      fontFamily: _selectedFont,
                      fontSize: 14,
                      fontWeight:
                          shiftFontWeight(FontWeight.w400, _weightDelta),
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Label (12 px)',
                    style: TextStyle(
                      fontFamily: _selectedFont,
                      fontSize: 12,
                      fontWeight:
                          shiftFontWeight(FontWeight.w500, _weightDelta),
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
