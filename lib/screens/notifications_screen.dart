import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import '../services/app_error_message.dart';
import '../theme/app_colors.dart';
import '../widgets/client_portal_surface.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = NotificationRepository();
    return Theme(
      data: ClientPortalSurface.theme(context),
      child: Scaffold(
        backgroundColor: const Color(0xFF180B07),
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            StreamBuilder<List<AppNotification>>(
              stream: repository.watchCurrentUserNotifications(),
              builder: (context, snapshot) {
                final notifications = snapshot.data ?? const [];
                final hasUnread = notifications.any((item) => !item.isRead);
                return TextButton(
                  onPressed: hasUnread
                      ? () => repository.markAllRead(notifications)
                      : null,
                  child: const Text('Mark all read'),
                );
              },
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: ClientPortalSurface(
          child: StreamBuilder<List<AppNotification>>(
            stream: repository.watchCurrentUserNotifications(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _NotificationMessage(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load notifications',
                  message: appErrorMessage(snapshot.error!),
                );
              }
              final notifications = snapshot.data ?? const [];
              if (notifications.isEmpty) {
                return const _NotificationMessage(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications yet',
                  message:
                      'Case, request, payment, and message updates will appear here.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return _NotificationTile(
                    notification: notification,
                    onTap: notification.isRead
                        ? null
                        : () => repository.markRead(notification.id),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: notification.isRead
        ? const Color(0xC935211A)
        : const Color(0xF04A2D22),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: notification.isRead
            ? Colors.white12
            : Primary.withValues(alpha: .6),
      ),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Primary.withValues(alpha: .14),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconFor(notification.type), color: Primary),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: notification.isRead
                                ? FontWeight.w700
                                : FontWeight.w900,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        const Padding(
                          padding: EdgeInsets.only(left: 8, top: 5),
                          child: CircleAvatar(
                            radius: 4,
                            backgroundColor: Primary,
                          ),
                        ),
                    ],
                  ),
                  if (notification.body.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        color: Color(0xFFE0D2CA),
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(context, notification.createdAt),
                    style: const TextStyle(
                      color: Color(0xFFBDAAA0),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  static IconData _iconFor(String type) {
    if (type.contains('chat')) return Icons.chat_bubble_outline_rounded;
    if (type.contains('review')) return Icons.star_outline_rounded;
    if (type.contains('paid') || type.contains('payment')) {
      return Icons.payments_outlined;
    }
    if (type.contains('accepted')) return Icons.check_circle_outline_rounded;
    if (type.contains('rejected')) return Icons.cancel_outlined;
    if (type.contains('case')) return Icons.work_outline_rounded;
    return Icons.notifications_none_rounded;
  }

  static String _formatTime(BuildContext context, DateTime value) {
    if (value.year == 1970) return 'Just now';
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    if (date == today) return 'Today, $time';
    if (date == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $time';
    }
    return '${MaterialLocalizations.of(context).formatCompactDate(local)}, $time';
  }
}

class _NotificationMessage extends StatelessWidget {
  const _NotificationMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 58, color: Primary),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFD8C8BE)),
          ),
        ],
      ),
    ),
  );
}
