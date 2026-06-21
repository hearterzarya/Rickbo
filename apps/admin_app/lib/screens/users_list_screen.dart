import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rickbo_core/rickbo_core.dart' hide muted, card, ink;
import '../theme.dart';

final usersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return AdminApi().users();
});

class UsersListScreen extends ConsumerWidget {
  const UsersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(usersProvider)),
        ],
      ),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Users load नहीं हुई: $e', style: TextStyle(color: danger)),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text('कोई user नहीं', style: TextStyle(color: muted)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(usersProvider);
              await ref.read(usersProvider.future);
            },
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final u = list[i];
                final banned = u['isBanned'] == true;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: banned ? danger.withValues(alpha: 0.2) : primary.withValues(alpha: 0.2),
                    child: Icon(Icons.person, color: banned ? danger : primary),
                  ),
                  title: Text(u['name']?.toString().isNotEmpty == true ? u['name'] : '(no name)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${u['phone']} · ${u['_count']?['rides'] ?? 0} rides · trust ${u['trustScore'] ?? 0}',
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                  trailing: banned
                      ? OutlinedButton(
                          onPressed: () => _unban(context, ref, u['id'] as String),
                          child: const Text('Unban'),
                        )
                      : TextButton(
                          onPressed: () => _ban(context, ref, u['id'] as String),
                          child: const Text('Ban', style: TextStyle(color: danger)),
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _ban(BuildContext ctx, WidgetRef ref, String id) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: card,
        title: Text('Ban user?', style: TextStyle(color: Colors.white)),
        content: Text('User login नहीं कर पाएगा', style: TextStyle(color: muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ban', style: TextStyle(color: danger))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await AdminApi().banUser(id);
      ref.invalidate(usersProvider);
    } catch (e) {
      if (ctx.mounted) _toast(ctx, 'Ban नहीं हुआ: $e', danger);
    }
  }

  Future<void> _unban(BuildContext ctx, WidgetRef ref, String id) async {
    try {
      await AdminApi().unbanUser(id);
      ref.invalidate(usersProvider);
    } catch (e) {
      if (ctx.mounted) _toast(ctx, 'Unban नहीं हुआ: $e', danger);
    }
  }
}

void _toast(BuildContext ctx, String m, Color c) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(m), backgroundColor: c));
}