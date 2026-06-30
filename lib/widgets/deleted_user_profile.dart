import 'package:flutter/material.dart';

class DeletedUserProfile {
  static const label = "Utilisateur n’existe plus";

  static bool isDeletedMap(Map<String, dynamic>? data) {
    if (data == null) return true;

    final status = (data['status'] ?? data['accountStatus'] ?? '')
        .toString()
        .toLowerCase()
        .trim();

    return data['deletedAt'] != null ||
        data['accountDeleted'] == true ||
        data['isDeleted'] == true ||
        data['disabled'] == true ||
        data['anonymized'] == true ||
        status == 'deleted' ||
        status == 'removed' ||
        status == 'disabled' ||
        status == 'anonymized';
  }

  static String displayName({
    required bool isDeleted,
    String? fallbackName,
  }) {
    if (isDeleted) return label;

    final clean = fallbackName?.trim();
    if (clean == null || clean.isEmpty) return 'Utilisateur';
    return clean;
  }
}

class DeletedUserAvatar extends StatelessWidget {
  const DeletedUserAvatar({
    super.key,
    this.radius = 22,
    this.iconSize,
  });

  final double radius;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade300,
      child: Icon(
        Icons.person_off_rounded,
        size: iconSize ?? radius,
        color: Colors.grey.shade700,
      ),
    );
  }
}

class DeletedUserIdentity extends StatelessWidget {
  const DeletedUserIdentity({
    super.key,
    this.radius = 22,
    this.textStyle,
    this.spacing = 10,
  });

  final double radius;
  final TextStyle? textStyle;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DeletedUserAvatar(radius: radius),
        SizedBox(width: spacing),
        Flexible(
          child: Text(
            DeletedUserProfile.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle ??
                TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class DeletedUserNotice extends StatelessWidget {
  const DeletedUserNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Row(
        children: [
          DeletedUserAvatar(radius: 16, iconSize: 17),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              DeletedUserProfile.label,
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
