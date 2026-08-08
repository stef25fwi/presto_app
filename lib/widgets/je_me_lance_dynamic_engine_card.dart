import 'package:flutter/material.dart';

import '../services/je_me_lance_decision_engine.dart';
import '../services/je_me_lance_mon_entreprise_api_service.dart';

class JeMeLanceDynamicEngineCard extends StatefulWidget {
  const JeMeLanceDynamicEngineCard({super.key});

  @override
  State<JeMeLanceDynamicEngineCard> createState() =>
      _JeMeLanceDynamicEngineCardState();
}

class _JeMeLanceDynamicEngineCardState
    extends State<JeMeLanceDynamicEngineCard> {
  static const Color _orange = Color(0xFFFF6600);
  static const Color _softBg = Color(0xFFFFF7F0);

  final _engine = const JeMeLanceDecisionEngine();
  final _api = const JeMeLanceMonEntrepriseApiService();

  JeMeLanceProfile _profile = JeMeLanceProfile.fonctionnaire;
  JeMeLanceActivityType _activity = JeMeLanceActivityType.restaurationSnack;
  JeMeLancePlaceType _place = JeMeLancePlaceType.localCommercial;
  JeMeLanceScale _scale = JeMeLanceScale.secondaire;

  bool _hasAssociates = false;
  bool _sellsAlcohol = false;
  bool _handlesAnimalFood = true;
  bool _plansEmployees = false;
  bool _wantsVatRecovery = false;
  bool _isDrom = true;

  double _monthlyRevenue = 4000;
  double _monthlyCharges = 1500;

  bool _apiLoading = false;
  MonEntrepriseSimulationResult? _apiResult;

  JeMeLanceProjectInput get _input => JeMeLanceProjectInput(
        profile: _profile,
        activityType: _activity,
        placeType: _place,
        scale: _scale,
        monthlyRevenue: _monthlyRevenue,
        monthlyCharges: _monthlyCharges,
        hasAssociates: _hasAssociates,
        sellsAlcohol: _sellsAlcohol,
        handlesAnimalFood: _handlesAnimalFood,
        plansEmployees: _plansEmployees,
        wantsVatRecovery: _wantsVatRecovery,
        isDrom: _isDrom,
      );

  Future<void> _runApiSimulation() async {
    setState(() {
      _apiLoading = true;
      _apiResult = null;
    });

    final result = await _api.simulateAutoEntrepreneurCommerce(
      annualRevenue: _input.annualRevenue,
      isDrom: _input.isDrom,
    );

    if (!mounted) return;
    setState(() {
      _apiResult = result;
      _apiLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _engine.evaluate(_input);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _softBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _orange.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 12),
          _form(),
          const SizedBox(height: 14),
          _verdict(result),
          const SizedBox(height: 12),
          _decisionBlock(
            title: 'Contrôles automatiques',
            icon: Icons.rule_rounded,
            children: result.controls
                .map(
                  (item) => _DecisionTile(
                    title: item.title,
                    detail: item.detail,
                    level: item.level,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          _decisionBlock(
            title: 'Statuts proposés dynamiquement',
            icon: Icons.account_balance_rounded,
            children: result.statuses
                .map(
                  (item) => _DecisionTile(
                    title: item.title,
                    detail: item.detail,
                    level: item.level,
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          _planBlock(result),
          const SizedBox(height: 10),
          _apiBlock(),
          const SizedBox(height: 10),
          _guichetBlock(result),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: const [
        CircleAvatar(
          radius: 18,
          backgroundColor: Color(0x1AFF6600),
          child: Icon(
            Icons.psychology_alt_rounded,
            color: _orange,
            size: 20,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Moteur automatique Je me lance',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF202124),
            ),
          ),
        ),
      ],
    );
  }

  Widget _form() {
    return Column(
      children: [
        _enumDropdown<JeMeLanceProfile>(
          label: 'Profil personnel',
          value: _profile,
          values: JeMeLanceProfile.values,
          labelBuilder: (value) => value.label,
          onChanged: (value) => setState(() => _profile = value),
        ),
        const SizedBox(height: 10),
        _enumDropdown<JeMeLanceActivityType>(
          label: 'Activité envisagée',
          value: _activity,
          values: JeMeLanceActivityType.values,
          labelBuilder: (value) => value.label,
          onChanged: (value) => setState(() => _activity = value),
        ),
        const SizedBox(height: 10),
        _enumDropdown<JeMeLancePlaceType>(
          label: 'Lieu d’exercice',
          value: _place,
          values: JeMeLancePlaceType.values,
          labelBuilder: (value) => value.label,
          onChanged: (value) => setState(() => _place = value),
        ),
        const SizedBox(height: 10),
        _enumDropdown<JeMeLanceScale>(
          label: 'Objectif',
          value: _scale,
          values: JeMeLanceScale.values,
          labelBuilder: (value) => value.label,
          onChanged: (value) => setState(() => _scale = value),
        ),
        const SizedBox(height: 12),
        _numberSlider(
          label: 'Chiffre d’affaires mensuel estimé',
          value: _monthlyRevenue,
          min: 0,
          max: 25000,
          step: 500,
          suffix: '€ / mois',
          onChanged: (value) => setState(() => _monthlyRevenue = value),
        ),
        _numberSlider(
          label: 'Charges mensuelles estimées',
          value: _monthlyCharges,
          min: 0,
          max: 15000,
          step: 250,
          suffix: '€ / mois',
          onChanged: (value) => setState(() => _monthlyCharges = value),
        ),
        _switchTile(
          title: 'Associés prévus',
          value: _hasAssociates,
          onChanged: (value) => setState(() => _hasAssociates = value),
        ),
        _switchTile(
          title: 'Vente d’alcool',
          value: _sellsAlcohol,
          onChanged: (value) => setState(() => _sellsAlcohol = value),
        ),
        _switchTile(
          title: 'Denrées animales / origine animale',
          value: _handlesAnimalFood,
          onChanged: (value) => setState(() => _handlesAnimalFood = value),
        ),
        _switchTile(
          title: 'Salarié prévu',
          value: _plansEmployees,
          onChanged: (value) => setState(() => _plansEmployees = value),
        ),
        _switchTile(
          title: 'Besoin de récupérer la TVA',
          value: _wantsVatRecovery,
          onChanged: (value) => setState(() => _wantsVatRecovery = value),
        ),
        _switchTile(
          title: 'Région DROM',
          value: _isDrom,
          onChanged: (value) => setState(() => _isDrom = value),
        ),
      ],
    );
  }

  Widget _enumDropdown<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T value) labelBuilder,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: values
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(labelBuilder(item)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        onChanged(value);
      },
    );
  }

  Widget _numberSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required String suffix,
    required ValueChanged<double> onChanged,
  }) {
    final divisions = ((max - min) / step).round();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label : ${value.round()} $suffix',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: '${value.round()}',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _switchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _verdict(JeMeLanceDecisionResult result) {
    final color = result.riskLevel.contains('Rouge')
        ? Colors.red
        : result.riskLevel.contains('Orange')
            ? Colors.orange
            : Colors.green;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verdict : ${result.verdict}',
              style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('Niveau de risque : ${result.riskLevel}'),
          const SizedBox(height: 5),
          Text('Statut recommandé : ${result.recommendedStatus}'),
        ],
      ),
    );
  }

  Widget _decisionBlock({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _orange, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (children.isEmpty)
            const Text('Aucun contrôle bloquant détecté.')
          else
            ...children,
        ],
      ),
    );
  }

  Widget _planBlock(JeMeLanceDecisionResult result) {
    return _decisionBlock(
      title: 'Plan personnalisé généré',
      icon: Icons.fact_check_rounded,
      children: [
        _BulletGroup(title: 'Avant création', items: result.beforeCreation),
        _BulletGroup(title: 'Création', items: result.creationSteps),
        _BulletGroup(title: 'Après SIRET', items: result.afterSiret),
        _BulletGroup(title: 'Documents à préparer', items: result.documents),
      ],
    );
  }

  Widget _apiBlock() {
    return _decisionBlock(
      title: 'Comparaison API Urssaf / Mon-entreprise',
      icon: Icons.api_rounded,
      children: [
        Text(
          'Simulation auto-entrepreneur commerce basée sur ${_input.annualRevenue.round()} € / an.',
          style: const TextStyle(height: 1.35),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _apiLoading ? null : _runApiSimulation,
          icon: _apiLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_sync_rounded),
          label: Text(_apiLoading
              ? 'Simulation en cours...'
              : 'Tester API Mon-entreprise'),
        ),
        if (_apiResult != null) ...[
          const SizedBox(height: 8),
          if (_apiResult!.success)
            _ApiResultTile(result: _apiResult!)
          else
            Text(
              _apiResult!.error ?? 'Erreur API inconnue.',
              style: const TextStyle(color: Colors.red, height: 1.35),
            ),
        ],
      ],
    );
  }

  Widget _guichetBlock(JeMeLanceDecisionResult result) {
    return _decisionBlock(
      title: 'Préparation Guichet unique INPI',
      icon: Icons.open_in_new_rounded,
      children: [
        const Text(
          'L’app prépare le dossier et les informations à saisir. Le dépôt officiel reste à faire sur le Guichet unique sécurisé.',
          style: TextStyle(height: 1.35),
        ),
        const SizedBox(height: 8),
        _BulletGroup(
          title: 'Données à préparer',
          items: result.guichetUniquePreparation,
        ),
      ],
    );
  }
}

class _DecisionTile extends StatelessWidget {
  final String title;
  final String detail;
  final String level;

  const _DecisionTile({
    required this.title,
    required this.detail,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(level,
              style: const TextStyle(
                color: Color(0xFF1A73E8),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              )),
          const SizedBox(height: 3),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(detail, style: const TextStyle(height: 1.32)),
        ],
      ),
    );
  }
}

class _BulletGroup extends StatelessWidget {
  final String title;
  final List<String> items;

  const _BulletGroup({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  Expanded(
                      child: Text(item, style: const TextStyle(height: 1.3))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiResultTile extends StatelessWidget {
  final MonEntrepriseSimulationResult result;

  const _ApiResultTile({required this.result});

  String _format(double? value) {
    if (value == null) return 'Non retourné';
    return '${value.round()} € / an';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Source : ${result.source}',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text('Cotisations estimées : ${_format(result.cotisations)}'),
        Text('Revenu net estimé : ${_format(result.revenuNet)}'),
        Text('Revenu après impôt : ${_format(result.revenuApresImpot)}'),
      ],
    );
  }
}
