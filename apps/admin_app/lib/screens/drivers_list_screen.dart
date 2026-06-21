import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rickbo_core/rickbo_core.dart' hide muted, card, ink;
import '../theme.dart';

final driversProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return AdminApi().drivers();
});

class DriversListScreen extends ConsumerWidget {
  const DriversListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drivers = ref.watch(driversProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drivers'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(driversProvider)),
        ],
      ),
      body: drivers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Drivers load नहीं हुई: $e', style: TextStyle(color: danger)),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Text('कोई driver नहीं', style: TextStyle(color: muted)));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(driversProvider);
              await ref.read(driversProvider.future);
            },
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final d = list[i];
                final status = d['status']?.toString() ?? 'PENDING';
                final online = d['isOnline'] == true;
                final verifiedA = d['aadhaarVerified'] == true;
                final verifiedP = d['policeVerified'] == true;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _statusColor(status).withValues(alpha: 0.2),
                    child: Icon(Icons.electric_rickshaw, color: _statusColor(status)),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          d['name']?.toString().isNotEmpty == true ? d['name'] : '(no name)',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                      _StatusPill(text: status, color: _statusColor(status)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: online ? success.withValues(alpha: 0.2) : muted.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(online ? 'ON' : 'OFF',
                            style: TextStyle(color: online ? success : muted, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${d['phone']} · ${d['rickshawNumber'] ?? 'no rickshaw'}',
                            style: TextStyle(color: muted, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _VerifyChip(label: 'Aadhaar', ok: verifiedA, onTap: () => _verifyAadhaar(ctx, ref, d['id'] as String)),
                            const SizedBox(width: 6),
                            _VerifyChip(label: 'Police', ok: verifiedP, onTap: () => _verifyPolice(ctx, ref, d['id'] as String)),
                            const SizedBox(width: 6),
                            Text('${d['_count']?['rides'] ?? 0} rides · ⭐ ${d['ratingAvg'] ?? '-'}',
                                style: TextStyle(color: muted, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: muted),
                    color: card2,
                    onSelected: (v) => _onAction(ctx, ref, v, d['id'] as String),
                    itemBuilder: (_) => [
                      if (status != 'ACTIVE') const PopupMenuItem(value: 'approve', child: Text('Approve → ACTIVE')),
                      if (status == 'ACTIVE') const PopupMenuItem(value: 'suspend', child: Text('Suspend')),
                      if (status != 'BANNED') const PopupMenuItem(value: 'ban', child: Text('Ban', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'ACTIVE': return success;
      case 'PENDING': return warning;
      case 'SUSPENDED': return warning;
      case 'BANNED': return danger;
      default: return muted;
    }
  }

  Future<void> _onAction(BuildContext ctx, WidgetRef ref, String action, String id) async {
    try {
      switch (action) {
        case 'approve': await AdminApi().approveDriver(id); break;
        case 'suspend': await AdminApi().suspendDriver(id); break;
        case 'ban': await AdminApi().banDriver(id); break;
      }
      ref.invalidate(driversProvider);
    } catch (e) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Action नहीं हुआ: $e')));
    }
  }

  Future<void> _verifyAadhaar(BuildContext ctx, WidgetRef ref, String id) async {
    try {
      await AdminApi().verifyAadhaar(id);
      ref.invalidate(driversProvider);
    } catch (e) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Aadhaar verify नहीं हुआ: $e')));
    }
  }

  Future<void> _verifyPolice(BuildContext ctx, WidgetRef ref, String id) async {
    try {
      await AdminApi().verifyPolice(id);
      ref.invalidate(driversProvider);
    } catch (e) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Police verify नहीं हुआ: $e')));
    }
  }
}

class _StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const _StatusPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _VerifyChip extends StatelessWidget {
  final String label;
  final bool ok;
  final VoidCallback onTap;
  const _VerifyChip({required this.label, required this.ok, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: ok ? success.withValues(alpha: 0.2) : border,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ok ? Icons.verified : Icons.verified_outlined, color: ok ? success : muted, size: 12),
            const SizedBox(width: 3),
            Text(label, style: TextStyle(color: ok ? success : muted, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}