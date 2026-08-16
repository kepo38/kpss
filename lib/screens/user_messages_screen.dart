import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/user_message_model.dart';
import '../services/user_message_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';

class UserMessagesScreen extends StatefulWidget {
  const UserMessagesScreen({super.key});

  @override
  State<UserMessagesScreen> createState() => _UserMessagesScreenState();
}

class _UserMessagesScreenState extends State<UserMessagesScreen> {
  final _svc = UserMessageService.instance;

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
          'Mesajlarım',
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
                        'Henüz mesaj yok.',
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
                  final m = items[i];
                  final tile = _MessageTile(
                    message: m,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UserMessageDetailScreen(message: m),
                        ),
                      );
                    },
                  );
                  if (!m.isRead) return tile;
                  return Dismissible(
                    key: ValueKey('msg_${m.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    ),
                    confirmDismiss: (_) async {
                      return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppTheme.inkSoft,
                              title: const Text(
                                'Mesajı sil',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: const Text(
                                'Bu mesaj profilinden kaldırılsın mı?',
                                style: TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('İptal'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text(
                                    'Sil',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                    },
                    onDismissed: (_) => _svc.deleteMessage(m.id),
                    child: tile,
                  );
                },
              ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final UserMessageModel message;
  final VoidCallback onTap;

  const _MessageTile({required this.message, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = message.createdAt;
    final dateText = date == null
        ? ''
        : DateFormat('d.M.yyyy').format(date.toLocal());

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
                  color: message.isRead
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppTheme.champagne,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: message.isRead
                            ? FontWeight.w500
                            : FontWeight.w700,
                        fontSize: 15,
                      ),
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
                    const SizedBox(height: 6),
                    Text(
                      message.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        height: 1.35,
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.55),
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
  }
}

class UserMessageDetailScreen extends StatefulWidget {
  final UserMessageModel message;

  const UserMessageDetailScreen({super.key, required this.message});

  @override
  State<UserMessageDetailScreen> createState() =>
      _UserMessageDetailScreenState();
}

class _UserMessageDetailScreenState extends State<UserMessageDetailScreen> {
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    UserMessageService.instance.markRead(widget.message.id);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.inkSoft,
        title: const Text(
          'Mesajı sil',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Bu mesaj profilinden kaldırılsın mı?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sil',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    final deleted =
        await UserMessageService.instance.deleteMessage(widget.message.id);
    if (!mounted) return;
    if (deleted) {
      Navigator.of(context).pop();
    } else {
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesaj silinemedi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.message;
    final date = m.createdAt;
    final dateText = date == null
        ? ''
        : DateFormat('d.M.yyyy · HH:mm').format(date.toLocal());

    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        foregroundColor: Colors.white,
        leading: const AppBackButton(),
        title: const Text(
          'Mesaj',
          style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Sil',
            onPressed: _deleting ? null : _delete,
            icon: _deleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.champagne,
                    ),
                  )
                : const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        children: [
          Text(
            m.title,
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
          const SizedBox(height: 22),
          Text(
            m.body,
            style: TextStyle(
              height: 1.55,
              fontSize: 16,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: _deleting ? null : _delete,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Mesajı sil'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.45)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
