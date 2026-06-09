import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:presto_app/features/business_guidance/pages/business_guidance_page.dart';
import 'package:presto_app/features/business_guidance/pages/business_project_sheet_page.dart';
import 'package:presto_app/features/trust/pages/professional_profile_page.dart';
import 'package:presto_app/features/trust/pages/siret_verification_page.dart';
import 'package:presto_app/features/trust/pages/user_reviews_page.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  static const Color _orange = Color(0xFFFF4B12);
  static const Color _blue = Color(0xFF1A5FE8);
  static const Color _dark = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _line = Color(0xFFE5E7EB);
  static const Color _softOrange = Color(0xFFFFF0EA);
  static const Color _softBlue = Color(0xFFEAF1FF);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = _displayName(user);
    final initials = _initials(displayName);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(26, 18, 26, 20),
                children: [
                  const _PrestoLogo(),
                  const SizedBox(height: 28),
                  _ProfileHeader(
                    displayName: displayName,
                    initials: initials,
                    photoUrl: user?.photoURL,
                  ),
                  const SizedBox(height: 30),
                  _TrustCard(
                    onProfessionalProfile: () =>
                        Navigator.of(context).pushNamed(
                      ProfessionalProfilePage.routeName,
                    ),
                    onSiret: () => Navigator.of(context).pushNamed(
                      SiretVerificationPage.routeName,
                    ),
                    onReviews: () => Navigator.of(context).pushNamed(
                      UserReviewsPage.routeName,
                    ),
                    onBusinessGuidance: () => Navigator.of(context).pushNamed(
                      BusinessGuidancePage.routeName,
                    ),
                    onProjectSheet: () => Navigator.of(context).pushNamed(
                      BusinessProjectSheetPage.routeName,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _AccountCard(
                    onLogout: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Déconnecté')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const _BottomAccountNav(),
          ],
        ),
      ),
    );
  }

  static String _displayName(User? user) {
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      final left = email.split('@').first;
      if (left.isNotEmpty) return left;
    }

    return 'Stef Stefan';
  }

  static String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'SS';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _PrestoLogo extends StatelessWidget {
  const _PrestoLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'ili',
                style: TextStyle(
                  color: AccountPage._orange,
                  fontSize: 44,
                  height: 0.95,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                ),
              ),
              TextSpan(
                text: 'prestō',
                style: TextStyle(
                  color: AccountPage._blue,
                  fontSize: 44,
                  height: 0.95,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Prestō',
          style: TextStyle(
            color: AccountPage._blue,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 0.95,
          ),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.initials,
    required this.photoUrl,
  });

  final String displayName;
  final String initials;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 104,
              height: 104,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: CircleAvatar(
                backgroundColor: const Color(0xFFEFF6FF),
                backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                    ? NetworkImage(photoUrl!)
                    : null,
                child: photoUrl == null || photoUrl!.isEmpty
                    ? Text(
                        initials,
                        style: const TextStyle(
                          color: AccountPage._blue,
                          fontWeight: FontWeight.w900,
                          fontSize: 28,
                        ),
                      )
                    : null,
              ),
            ),
            Positioned(
              right: -4,
              bottom: 3,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AccountPage._blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 28),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AccountPage._dark,
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: AccountPage._blue,
                    size: 22,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Guadeloupe • Les Abymes',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AccountPage._dark,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AccountPage._softBlue,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user,
                      color: AccountPage._blue,
                      size: 18,
                    ),
                    SizedBox(width: 7),
                    Text(
                      'Profil vérifié',
                      style: TextStyle(
                        color: AccountPage._blue,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrustCard extends StatelessWidget {
  const _TrustCard({
    required this.onProfessionalProfile,
    required this.onSiret,
    required this.onReviews,
    required this.onBusinessGuidance,
    required this.onProjectSheet,
  });

  final VoidCallback onProfessionalProfile;
  final VoidCallback onSiret;
  final VoidCallback onReviews;
  final VoidCallback onBusinessGuidance;
  final VoidCallback onProjectSheet;

  @override
  Widget build(BuildContext context) {
    return _RoundedCard(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: AccountPage._orange,
                size: 43,
              ),
              SizedBox(width: 18),
              Expanded(
                child: Text(
                  'Espace confiance et activité',
                  style: TextStyle(
                    color: AccountPage._orange,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _MenuTile(
            icon: Icons.badge_outlined,
            color: AccountPage._orange,
            background: AccountPage._softOrange,
            label: 'Ma fiche Pro',
            onTap: onProfessionalProfile,
          ),
          _MenuTile(
            icon: Icons.business_outlined,
            color: AccountPage._orange,
            background: AccountPage._softOrange,
            label: 'Vérifier mon SIRET',
            onTap: onSiret,
          ),
          _MenuTile(
            icon: Icons.star_border_rounded,
            color: AccountPage._orange,
            background: AccountPage._softOrange,
            label: 'Mes avis',
            onTap: onReviews,
          ),
          _MenuTile(
            icon: Icons.add_circle,
            color: AccountPage._orange,
            background: AccountPage._softOrange,
            label: 'Créer mon activité',
            onTap: onBusinessGuidance,
          ),
          _MenuTile(
            icon: Icons.folder_outlined,
            color: AccountPage._orange,
            background: AccountPage._softOrange,
            label: 'Ma fiche projet',
            onTap: onProjectSheet,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return _RoundedCard(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Column(
        children: [
          _MenuTile(
            icon: Icons.chat_bubble_outline_rounded,
            color: AccountPage._blue,
            background: Colors.transparent,
            label: 'Mes messages',
            onTap: () => Navigator.of(context).pushNamed('/messages'),
          ),
          _MenuTile(
            icon: Icons.campaign_rounded,
            color: AccountPage._blue,
            background: Colors.transparent,
            label: 'Mes annonces',
            onTap: () => Navigator.of(context).pushNamed('/my-offers'),
          ),
          _MenuTile(
            icon: Icons.settings_rounded,
            color: AccountPage._blue,
            background: Colors.transparent,
            label: 'Paramètres',
            onTap: () => Navigator.of(context).pushNamed('/settings'),
          ),
          _MenuTile(
            icon: Icons.logout_rounded,
            color: AccountPage._blue,
            background: Colors.transparent,
            label: 'Déconnexion',
            onTap: onLogout,
            showDivider: false,
            showChevron: false,
          ),
        ],
      ),
    );
  }
}

class _RoundedCard extends StatelessWidget {
  const _RoundedCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.background,
    required this.label,
    required this.onTap,
    this.showDivider = true,
    this.showChevron = true,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String label;
  final VoidCallback onTap;
  final bool showDivider;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: color, size: 29),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 22,
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (showChevron)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF7A7F87),
                    size: 32,
                  ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 1,
            indent: 68,
            color: AccountPage._line,
          ),
      ],
    );
  }
}

class _BottomAccountNav extends StatelessWidget {
  const _BottomAccountNav();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _BottomItem(
              icon: Icons.search_rounded,
              label: 'Consulter',
              color: const Color(0xFF6B7280),
              onTap: () => Navigator.of(context).pushNamed('/'),
            ),
            _PublishBottomItem(
              onTap: () => Navigator.of(context).pushNamed('/publish'),
            ),
            _BottomItem(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Messages',
              color: const Color(0xFF6B7280),
              onTap: () => Navigator.of(context).pushNamed('/messages'),
            ),
            _BottomItem(
              icon: Icons.person_rounded,
              label: 'Compte',
              color: AccountPage._blue,
              isActive: true,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            if (isActive)
              Container(
                margin: const EdgeInsets.only(top: 0),
                width: 64,
                height: 4,
                decoration: BoxDecoration(
                  color: AccountPage._blue,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 34),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublishBottomItem extends StatelessWidget {
  const _PublishBottomItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.only(top: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AccountPage._orange,
                child: Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Publier',
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
