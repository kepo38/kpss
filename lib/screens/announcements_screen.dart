import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/announcement_model.dart';
import '../services/announcement_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';

String _fmtDate(DateTime? date, {bool withTime = false}) {
  if (date == null) return '';
  final local = date.toLocal();
  if (withTime) {
    return DateFormat('d.M.yyyy · HH:mm').format(local);
  }
  return DateFormat('d.M.yyyy').format(local);
}

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _svc = AnnouncementService.instance;

  @override
  void initState() {
    super.initState();
    _svc.addListener(_onChanged);
    _svc.refresh();
  }

  @override
  void dispose() {
    _svc.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = _svc.items;
    final unread = _svc.unreadCount;

    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        foregroundColor: Colors.white,
        leading: const AppBackButton(),
        title: const Text(
          'Duyurular',
          style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w600),
        ),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: () => _svc.markAllRead(),
              child: const Text(
                'Tümünü okundu',
                style: TextStyle(color: AppTheme.champagne, fontSize: 13),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.champagne,
        onRefresh: _svc.refresh,
        child: items.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: Center(
                      child: Text(
                        'Henüz duyuru yok.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final a = items[i];
                  final read = _svc.isRead(a.id);
                  return _AnnouncementTile(
                    announcement: a,
                    isRead: read,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AnnouncementDetailScreen(
                            announcement: a,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  final AnnouncementModel announcement;
  final bool isRead;
  final VoidCallback onTap;

  const _AnnouncementTile({
    required this.announcement,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = _fmtDate(announcement.createdAt);
    final preview = announcement.body.trim().isNotEmpty
        ? announcement.body
        : (announcement.hasImage ? 'Fotoğraf duyurusu' : '');

    return Material(
      color: AppTheme.inkSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRead
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppTheme.champagne,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            announcement.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight:
                                  isRead ? FontWeight.w500 : FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isRead
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : AppTheme.champagne.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            isRead ? 'Okundu' : 'Okunmadı',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isRead
                                  ? Colors.white.withValues(alpha: 0.45)
                                  : AppTheme.champagneLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (dateText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        dateText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                    if (announcement.hasImage) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            announcement.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => ColoredBox(
                              color: Colors.white.withValues(alpha: 0.06),
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (preview.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          height: 1.35,
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.55),
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

class AnnouncementDetailScreen extends StatefulWidget {
  final AnnouncementModel announcement;

  const AnnouncementDetailScreen({super.key, required this.announcement});

  @override
  State<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  @override
  void initState() {
    super.initState();
    AnnouncementService.instance.markRead(widget.announcement.id);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.announcement;
    final dateText = _fmtDate(a.createdAt, withTime: true);

    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        foregroundColor: Colors.white,
        leading: const AppBackButton(),
        title: const Text(
          'Duyuru',
          style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        children: [
          Text(
            a.title,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.15,
            ),
          ),
          if (dateText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              dateText,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ],
          if (a.hasImage) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                child: Image.network(
                  a.imageUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    alignment: Alignment.center,
                    color: Colors.white.withValues(alpha: 0.06),
                    child: Text(
                      'Görsel yüklenemedi',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (a.body.trim().isNotEmpty) ...[
            const SizedBox(height: 22),
            Text(
              a.body,
              style: TextStyle(
                height: 1.55,
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
