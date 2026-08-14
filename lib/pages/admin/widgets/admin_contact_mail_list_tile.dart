import 'package:flutter/material.dart';

import 'admin_contact_mail_models.dart';

class AdminContactMailListTile extends StatelessWidget {
  final AdminContactMailItem item;
  final VoidCallback onTap;

  const AdminContactMailListTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isRead
                  ? const Color(0xFFE5E7EB)
                  : const Color(0xFFFFB380),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusIcon(isRead: item.isRead),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.senderLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF111827),
                              fontSize: 13,
                              fontWeight: item.isRead
                                  ? FontWeight.w700
                                  : FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatAdminContactMailDate(item.receivedAt),
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subject.isEmpty ? '(Sans objet)' : item.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF374151),
                        fontSize: 12.5,
                        fontWeight:
                            item.isRead ? FontWeight.w600 : FontWeight.w800,
                      ),
                    ),
                    if (item.preview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final bool isRead;

  const _StatusIcon({required this.isRead});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isRead ? const Color(0xFFF3F4F6) : const Color(0xFFFFF0E6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isRead ? Icons.drafts_outlined : Icons.mark_email_unread_rounded,
        color: isRead ? const Color(0xFF6B7280) : const Color(0xFFFF6600),
        size: 20,
      ),
    );
  }
}
