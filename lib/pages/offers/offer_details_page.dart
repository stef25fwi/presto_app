import 'package:flutter/material.dart';

// ─── Data models ─────────────────────────────────────────────────────────────

enum OfferActionType { booking, contact }

class PracticalInfo {
  final String category;
  final String serviceArea;
  final bool canTravel;
  final String schedule;
  final String averageDelay;
  final String paymentMethod;
  final String serviceType;

  const PracticalInfo({
    required this.category,
    required this.serviceArea,
    required this.canTravel,
    required this.schedule,
    required this.averageDelay,
    required this.paymentMethod,
    required this.serviceType,
  });
}

class Advertiser {
  final String id;
  final String name;
  final bool verified;
  final double rating;
  final int offersCount;
  final int reviewsCount;
  final String seniorityLabel;
  final String city;
  final String bio;
  final String avatarUrl;
  final bool isOnline;
  final String lastSeenLabel;

  const Advertiser({
    required this.id,
    required this.name,
    required this.verified,
    required this.rating,
    required this.offersCount,
    this.reviewsCount = 0,
    required this.seniorityLabel,
    required this.city,
    required this.bio,
    required this.avatarUrl,
    required this.isOnline,
    required this.lastSeenLabel,
  });
}

class Offer {
  final String id;
  final String title;
  final double price;
  final String category;
  final String city;
  final String publishedAtLabel;
  final String availability;
  final String shortDescription;
  final String description;
  final String phone;
  final List<String> imageUrls;
  final List<String> statusBadges;
  final PracticalInfo practicalInfo;
  final Advertiser advertiser;
  final OfferActionType actionType;
  final List<Offer> similarOffers;

  const Offer({
    required this.id,
    required this.title,
    required this.price,
    required this.category,
    required this.city,
    required this.publishedAtLabel,
    required this.availability,
    required this.shortDescription,
    required this.description,
    required this.phone,
    required this.imageUrls,
    required this.statusBadges,
    required this.practicalInfo,
    required this.advertiser,
    required this.actionType,
    required this.similarOffers,
  });
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class OfferDetailsPage extends StatelessWidget {
  final Object? offer;
  final String currentUserId;

  OfferDetailsPage({
    super.key,
    this.offer,
    this.currentUserId = 'buyer_demo_001',
  });

  @override
  Widget build(BuildContext context) {
    return PrestoOfferDetailsPage(offer: offer);
  }
}

class PrestoOfferDetailsPage extends StatelessWidget {
  final Object? offer;

  const PrestoOfferDetailsPage({super.key, this.offer});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF6EFEC);
    final data = _OfferUiData.fromOffer(offer);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompactMobile = screenWidth <= 360;
    final sectionGap = isCompactMobile ? 12.0 : 14.0;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          const _BackgroundDecor(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                isCompactMobile ? 14 : 16,
                isCompactMobile ? 10 : 12,
                isCompactMobile ? 14 : 16,
                isCompactMobile ? 20 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopHeader(title: data.title, compact: isCompactMobile),
                  SizedBox(height: sectionGap),
                  _HeroCard(data: data, compact: isCompactMobile),
                  SizedBox(height: sectionGap),
                  _PracticalInfoCard(data: data, compact: isCompactMobile),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferUiData {
  final String title;
  final String detail;
  final String city;
  final String category;
  final String description;
  final String phone;
  final String publishedAtLabel;
  final String availability;
  final double price;
  final OfferActionType actionType;
  final List<String> statusBadges;

  final String advertiserName;
  final String advertiserRole;
  final String advertiserAvatarUrl;
  final double advertiserRating;
  final int advertiserReviewCount;
  final bool verified;

  final String serviceArea;
  final bool canTravel;
  final String schedule;
  final String averageDelay;
  final String paymentMethod;
  final String serviceType;

  const _OfferUiData({
    required this.title,
    required this.detail,
    required this.city,
    required this.category,
    required this.description,
    required this.phone,
    required this.publishedAtLabel,
    required this.availability,
    required this.price,
    required this.actionType,
    required this.statusBadges,
    required this.advertiserName,
    required this.advertiserRole,
    required this.advertiserAvatarUrl,
    required this.advertiserRating,
    required this.advertiserReviewCount,
    required this.verified,
    required this.serviceArea,
    required this.canTravel,
    required this.schedule,
    required this.averageDelay,
    required this.paymentMethod,
    required this.serviceType,
  });

  factory _OfferUiData.fromOffer(Object? offer) {
    final dynamic o = offer;
    final dynamic advertiser = _read(() => o.advertiser);
    final dynamic practical = _read(() => o.practicalInfo);

    final title = _asString(_read(() => o.title), fallback: 'Montage meuble');
    final detail = _asString(_read(() => o.shortDescription), fallback: '+ fixation TV');
    final city = _asString(_read(() => o.city), fallback: 'Les Abymes');
    final category = _asString(_read(() => o.category), fallback: 'Bricolage');

    final fullDescription = _asString(
      _read(() => o.description),
      fallback: 'Montage d\'un petit meuble + fixation d\'une\nTV au mur (support déjà acheté). Mur béton.\nPrévoir perceuse.',
    );
    final phone = _asString(_read(() => o.phone), fallback: '');
    final publishedAtLabel = _asString(
      _read(() => o.publishedAtLabel),
      fallback: 'Publication récente',
    );
    final availability = _asString(
      _read(() => o.availability),
      fallback: 'Disponibilité à confirmer',
    );
    final actionType = _read(() => o.actionType) is OfferActionType
        ? _read(() => o.actionType) as OfferActionType
        : OfferActionType.contact;
    final statusBadges = _asStringList(_read(() => o.statusBadges));

    final price = _asDouble(_read(() => o.price), fallback: 90);

    final advertiserName = _asString(_read(() => advertiser.name), fallback: 'Bastien');
    final advertiserRole = _asString(_read(() => advertiser.bio), fallback: 'Bricoleur expérimenté');
    final advertiserAvatarUrl = _asString(_read(() => advertiser.avatarUrl), fallback: '');
    final advertiserRating = _asDouble(_read(() => advertiser.rating), fallback: 4.9);
    final advertiserReviewCount = _asInt(
      _read(() => advertiser.reviewsCount) ?? _read(() => advertiser.reviewCount),
      fallback: 0,
    );
    final verified = _asBool(_read(() => advertiser.verified), fallback: true);

    final serviceArea = _asString(_read(() => practical.serviceArea), fallback: city);
    final canTravel = _asBool(_read(() => practical.canTravel), fallback: true);
    final schedule = _asString(_read(() => practical.schedule), fallback: 'Horaires à convenir');
    final averageDelay = _asString(_read(() => practical.averageDelay), fallback: '30 min en moyenne');
    final paymentMethod = _asString(_read(() => practical.paymentMethod), fallback: 'Paiement à convenir');
    final serviceType = _asString(_read(() => practical.serviceType), fallback: 'Prestation ponctuelle');

    return _OfferUiData(
      title: title,
      detail: detail,
      city: city,
      category: category,
      description: fullDescription,
      phone: phone,
      publishedAtLabel: publishedAtLabel,
      availability: availability,
      price: price,
      actionType: actionType,
      statusBadges: statusBadges,
      advertiserName: advertiserName,
      advertiserRole: advertiserRole,
      advertiserAvatarUrl: advertiserAvatarUrl,
      advertiserRating: advertiserRating,
      advertiserReviewCount: advertiserReviewCount,
      verified: verified,
      serviceArea: serviceArea,
      canTravel: canTravel,
      schedule: schedule,
      averageDelay: averageDelay,
      paymentMethod: paymentMethod,
      serviceType: serviceType,
    );
  }

  static dynamic _read(dynamic Function() getter) {
    try {
      return getter();
    } catch (_) {
      return null;
    }
  }

  static String _asString(dynamic value, {required String fallback}) {
    if (value == null) return fallback;
    final s = value.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  static double _asDouble(dynamic value, {required double fallback}) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.replaceAll(',', '.'));
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static int _asInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  static bool _asBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    return fallback;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }
}

class _BackgroundDecor extends StatelessWidget {
  const _BackgroundDecor();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: ColoredBox(color: Color(0xFFF6EFEC)),
        ),
        Positioned(
          left: -60,
          bottom: 120,
          child: IgnorePointer(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1976F3).withOpacity(0.12),
                    const Color(0xFF1976F3).withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopHeader extends StatelessWidget {
  final String title;
  final bool compact;

  const _TopHeader({required this.title, this.compact = false});

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF7A14);
    const blueDeep = Color(0xFF0459D9);

    return SizedBox(
      height: compact ? 40 : 44,
      child: Row(
        children: [
          _CircleIconButton(
            icon: Icons.arrow_back_rounded,
            iconColor: orange,
            size: compact ? 18 : 20,
            compact: compact,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          SizedBox(width: compact ? 8 : 10),
          Expanded(
            child: Text(
              _truncatedTitle(title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: blueDeep,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                height: 1.0,
              ).copyWith(fontSize: compact ? 20 : 22),
            ),
          ),
          _CircleIconButton(
            icon: Icons.notifications_none_rounded,
            iconColor: blueDeep,
            size: compact ? 18 : 20,
            compact: compact,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  String _truncatedTitle(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Montage me...';
    return trimmed.length > 12 ? '${trimmed.substring(0, 10)}...' : trimmed;
  }
}

class _HeroCard extends StatelessWidget {
  final _OfferUiData data;
  final bool compact;

  const _HeroCard({required this.data, this.compact = false});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF162038);
    const body = Color(0xFF1F2740);
    const orange = Color(0xFFFF7B12);
    const orangeLight = Color(0xFFFFB34B);
    const chipBg = Color(0xFFF1EFF7);

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 22,
        compact ? 18 : 22,
        compact ? 18 : 22,
        compact ? 18 : 22,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 26 : 30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B8E86).withOpacity(0.10),
            blurRadius: compact ? 18 : 22,
            offset: Offset(0, compact ? 8 : 10),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.85),
            blurRadius: compact ? 6 : 8,
            offset: Offset(0, compact ? -1 : -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title,
            style: TextStyle(
              color: navy,
              fontSize: compact ? 26 : 30,
              fontWeight: FontWeight.w800,
              height: 1.0,
              letterSpacing: compact ? -0.9 : -1.0,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: data.detail,
                  style: TextStyle(
                    color: navy,
                    fontSize: compact ? 20 : 22,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                    letterSpacing: compact ? -0.7 : -0.8,
                  ),
                ),
                TextSpan(
                  text: ' - ${data.city}',
                  style: TextStyle(
                    color: navy,
                    fontSize: compact ? 16 : 18,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                    letterSpacing: compact ? -0.4 : -0.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 14 : 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${data.price.toStringAsFixed(0)} €',
                style: TextStyle(
                  color: orange,
                  fontSize: compact ? 52 : 60,
                  fontWeight: FontWeight.w800,
                  height: 0.95,
                  letterSpacing: compact ? -1.6 : -1.9,
                ),
              ),
              SizedBox(width: compact ? 10 : 12),
              Expanded(
                child: Container(
                  height: compact ? 38 : 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    gradient: const LinearGradient(
                      colors: [orangeLight, orange],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: orange.withOpacity(0.26),
                        blurRadius: compact ? 10 : 12,
                        offset: Offset(0, compact ? 5 : 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_rounded, color: Colors.white, size: compact ? 16 : 18),
                      SizedBox(width: compact ? 4 : 6),
                      Text(
                        'Réponse rapide',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 13 : 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 12 : 14),
          Row(
            children: [
              Expanded(
                child: _TagChip(
                  icon: Icons.handyman_outlined,
                  text: data.category,
                  bg: chipBg,
                  compact: compact,
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: _TagChip(
                  icon: Icons.location_on_outlined,
                  text: data.city,
                  bg: chipBg,
                  compact: compact,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 14 : 18),
          Text(
            data.description,
            style: TextStyle(
              color: body,
              fontSize: compact ? 15 : 16,
              fontWeight: FontWeight.w500,
              height: 1.48,
              letterSpacing: compact ? -0.1 : -0.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticalInfoCard extends StatelessWidget {
  final _OfferUiData data;
  final bool compact;

  const _PracticalInfoCard({required this.data, this.compact = false});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF18233D);
    const blue = Color(0xFF0459D9);
    const blueSoft = Color(0xFFDCEBFF);
    const muted = Color(0xFF6F7282);
    const line = Color(0xFFE6E3E6);
    const orange = Color(0xFFFF7B12);
    const green = Color(0xFF45B36B);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(compact ? 28 : 32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B8E86).withOpacity(0.10),
            blurRadius: compact ? 18 : 22,
            offset: Offset(0, compact ? 8 : 10),
          ),
          BoxShadow(
            color: blueSoft.withOpacity(0.55),
            blurRadius: compact ? 15 : 18,
            spreadRadius: 1,
            offset: Offset(0, compact ? 11 : 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 18,
              compact ? 14 : 16,
              compact ? 16 : 18,
              compact ? 10 : 12,
            ),
            child: Row(
              children: [
                Text(
                  'Informations pratiques',
                  style: TextStyle(
                    color: blue,
                    fontSize: compact ? 20 : 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFBFAFA),
              borderRadius: BorderRadius.circular(compact ? 20 : 24),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 14 : 18,
                compact ? 12 : 16,
                compact ? 14 : 18,
                compact ? 14 : 18,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _AdvertiserAvatar(
                        name: data.advertiserName,
                        avatarUrl: data.advertiserAvatarUrl,
                        compact: compact,
                      ),
                      SizedBox(width: compact ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: data.advertiserName,
                                    style: TextStyle(
                                      color: navy,
                                      fontSize: compact ? 17 : 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ', ${data.advertiserRole}',
                                    style: TextStyle(
                                      color: navy,
                                      fontSize: compact ? 15 : 17,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: compact ? 5 : 6),
                            Row(
                              children: [
                                Icon(Icons.star_rounded, color: orange, size: compact ? 15 : 18),
                                SizedBox(width: compact ? 4 : 5),
                                Text(
                                  data.advertiserRating.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: orange,
                                    fontSize: compact ? 14 : 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(width: compact ? 5 : 8),
                                Text(
                                  data.advertiserReviewCount > 0
                                      ? '(${data.advertiserReviewCount} avis)'
                                      : '(0 avis)',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: compact ? 13 : 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 10 : 14,
                          vertical: compact ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F7F2),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(
                            color: const Color(0xFFDCEADB),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: data.verified ? green : muted,
                              size: compact ? 14 : 16,
                            ),
                            SizedBox(width: compact ? 5 : 6),
                            Text(
                              data.verified ? 'Vérifié' : 'Profil',
                              style: TextStyle(
                                color: navy,
                                fontSize: compact ? 12 : 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 10 : 14),
                  const Divider(height: 1, thickness: 1, color: line),
                  _InfoLine(
                    icon: Icons.handyman_outlined,
                    label: 'Catégorie',
                    value: data.category,
                    compact: compact,
                  ),
                  _InfoLine(
                    icon: Icons.map_outlined,
                    label: 'Zone d\'intervention',
                    value: data.serviceArea,
                    compact: compact,
                  ),
                  _InfoLine(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Déplacement possible',
                    value: data.canTravel ? 'Oui' : 'Non',
                    compact: compact,
                  ),
                  _InfoLine(
                    icon: Icons.access_time_rounded,
                    label: 'Horaires',
                    value: data.schedule,
                    compact: compact,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: compact ? 12 : 14),
                    child: Row(
                      children: [
                        Icon(Icons.wallet_outlined, color: muted, size: compact ? 21 : 24),
                        SizedBox(width: compact ? 9 : 12),
                        Text(
                          'Délai moyen',
                          style: TextStyle(
                            color: muted,
                            fontSize: compact ? 15 : 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.bolt_rounded, color: orange, size: compact ? 15 : 18),
                        SizedBox(width: compact ? 4 : 5),
                        Text(
                          'Réponse rapide',
                          style: TextStyle(
                            color: orange,
                            fontSize: compact ? 13 : 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: compact ? 5 : 8),
                        _DelayBadge(text: data.averageDelay, compact: compact),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: line),
                  _InfoLine(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Mode de paiement',
                    value: data.paymentMethod,
                    compact: compact,
                  ),
                  _InfoLine(
                    icon: Icons.work_outline_rounded,
                    label: 'Type de prestation',
                    value: data.serviceType,
                    iconColor: blue,
                    showDivider: false,
                    compact: compact,
                  ),
                  SizedBox(height: compact ? 12 : 14),
                  _InlineCta(
                    label: data.actionType == OfferActionType.booking ? 'Réserver maintenant' : 'Proposer mes services',
                    compact: compact,
                  ),
                  SizedBox(height: compact ? 12 : 14),
                  Row(
                    children: [
                      Expanded(child: Divider(height: 1, thickness: 1, color: line)),
                      SizedBox(width: compact ? 7 : 10),
                      Icon(Icons.access_time_rounded, color: muted, size: compact ? 13 : 15),
                      SizedBox(width: compact ? 4 : 5),
                      Text(
                        'Réponse en moins d\'une heure',
                        style: TextStyle(
                          color: muted,
                          fontSize: compact ? 12 : 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: compact ? 7 : 10),
                      Expanded(child: Divider(height: 1, thickness: 1, color: line)),
                    ],
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

class _TagChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color bg;
  final bool compact;

  const _TagChip({
    required this.icon,
    required this.text,
    required this.bg,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF18233D);

    return Container(
      height: compact ? 44 : 48,
      padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: navy, size: compact ? 16 : 18),
          SizedBox(width: compact ? 5 : 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: navy,
                fontSize: compact ? 15 : 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final bool showDivider;
  final bool compact;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = const Color(0xFF6C7384),
    this.showDivider = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF18233D);
    const muted = Color(0xFF6F7282);
    const line = Color(0xFFE6E3E6);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: compact ? 20 : 22),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: muted,
                    fontSize: compact ? 15 : 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: navy,
                    fontSize: compact ? 15 : 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.15,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, thickness: 1, color: line),
      ],
    );
  }
}

class _DelayBadge extends StatelessWidget {
  final String text;
  final bool compact;

  const _DelayBadge({required this.text, this.compact = false});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF0459D9);
    const muted = Color(0xFF6F7282);

    final normalized = text.trim().isEmpty ? '30 min en moyenne' : text.trim();
    final parts = normalized.split(' en moyenne');
    final headline = parts.first.trim();
    final subline = normalized.contains('en moyenne') ? 'en moyenne' : '';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(compact ? 9 : 10),
        border: Border.all(
          color: const Color(0xFFDBE6FA),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            headline,
            style: TextStyle(
              color: blue,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          if (subline.isNotEmpty) ...[
            SizedBox(height: compact ? 0.5 : 1),
            Text(
              subline,
              style: TextStyle(
                color: muted,
                fontSize: compact ? 8 : 9,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineCta extends StatelessWidget {
  final String label;
  final bool compact;

  const _InlineCta({required this.label, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 56 : 62,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF49A6FF), Color(0xFF0058DF)],
        ),
        borderRadius: BorderRadius.circular(100),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A63E7).withOpacity(0.35),
            blurRadius: compact ? 15 : 18,
            offset: Offset(0, compact ? 7 : 8),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.35),
            blurRadius: compact ? 5 : 6,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: () {},
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 16),
            child: Row(
              children: [
                Container(
                  width: compact ? 28 : 30,
                  height: compact ? 28 : 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(compact ? 7 : 8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.28),
                    ),
                  ),
                  child: Icon(
                    Icons.mail_outline_rounded,
                    color: Colors.white,
                    size: compact ? 16 : 18,
                  ),
                ),
                SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 17 : 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: compact ? 14 : 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdvertiserAvatar extends StatelessWidget {
  final String name;
  final String avatarUrl;
  final bool compact;

  const _AdvertiserAvatar({required this.name, required this.avatarUrl, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final initials = _buildInitials(name);

    return Container(
      width: compact ? 52 : 58,
      height: compact ? 52 : 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: compact ? 1.5 : 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: compact ? 6 : 8,
            offset: Offset(0, compact ? 2 : 3),
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7D25B), Color(0xFFC98E27)],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl.isNotEmpty
          ? Image.network(
              avatarUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _AvatarFallback(initials: initials),
            )
          : _AvatarFallback(initials: initials),
    );
  }

  String _buildInitials(String value) {
    final parts = value
        .split(RegExp(r'\s+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final double size;
  final VoidCallback onTap;
  final bool compact;

  const _CircleIconButton({
    required this.icon,
    required this.iconColor,
    required this.size,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        radius: compact ? 20 : 22,
        onTap: onTap,
        child: SizedBox(
          width: compact ? 28 : 30,
          height: compact ? 28 : 30,
          child: Icon(
            icon,
            color: iconColor,
            size: size,
          ),
        ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String initials;

  const _AvatarFallback({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7D25B), Color(0xFFC98E27)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            bottom: 0,
            left: 4,
            right: 4,
            child: Container(
              height: 13,
              decoration: const BoxDecoration(
                color: Color(0xFFDAA065),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Positioned(
            top: 7,
            left: 9,
            child: CircleAvatar(
              radius: 2,
              backgroundColor: Color(0xFF50371E),
            ),
          ),
          const Positioned(
            top: 7,
            right: 9,
            child: CircleAvatar(
              radius: 2,
              backgroundColor: Color(0xFF50371E),
            ),
          ),
          Positioned(
            top: 12,
            left: 9,
            right: 9,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5A31).withOpacity(0.85),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          if (initials.isNotEmpty)
            Align(
              alignment: const Alignment(0, 0.9),
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.transparent,
                  fontSize: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
