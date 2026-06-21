import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rickbo_core/rickbo_core.dart' hide muted, card, ink;
import '../theme.dart';

class RidesListScreen extends ConsumerStatefulWidget {
  const RidesListScreen({super.key});
  @override
  ConsumerState<RidesListScreen> createState() => _RidesListScreenState();
}

class _RidesListScreenState extends ConsumerState<RidesListScreen> {
  String? _statusFilter;
  late final ridesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
    return AdminApi().rides(status: _statusFilter);
  });

  @override
  Widget build(BuildContext context) {
    final rides = ref.watch(ridesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rides'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(ridesProvider)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _filterChip('All', null),
                _filterChip('Requested', 'REQUESTED'),
                _filterChip('Matched', 'MATCHED'),
                _filterChip('Ongoing', 'ONGOING'),
                _filterChip('Completed', 'COMPLETED'),
                _filterChip('Cancelled', 'CANCELLED'),
              ],
            ),
          ),
        ),
      ),
      body: rides.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Rides load नहीं हुई: $e', style: GoogleFonts.hind(color: danger)),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(child: Text('कोई ride नहीं', style: GoogleFonts.hind(color: muted)));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(ridesProvider);
              await ref.read(ridesProvider.future);
            },
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final r = list[i];
                final status = r['status']?.toString() ?? '?';
                final user = r['user'] as Map?;
                final driver = r['driver'] as Map?;
                return ListTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text('${r['fromZone']} → ${r['toZone']} · ₹${r['fare']}',
                            style: GoogleFonts.baloo2(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                      _statusPill(status),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '👤 ${user?['phone'] ?? '?'}\n'
                      '🛺 ${driver?['rickshawNumber'] ?? driver?['phone'] ?? 'no driver'}\n'
                      '${_fmtTime(r['requestedAt']?.toString())}',
                      style: GoogleFonts.hind(color: muted, fontSize: 12, height: 1.4),
                    ),
                  ),
                  isThreeLine: true,
                  trailing: (status == 'REQUESTED' || status == 'MATCHED' || status == 'ONGOING')
                      ? IconButton(
                          icon: const Icon(Icons.cancel, color: danger),
                          tooltip: 'Cancel ride',
                          onPressed: () => _cancel(ctx, ref, ridesProvider, r['id'] as String),
                        )
                      : null,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _filterChip(String label, String? val) {
    final selected = _statusFilter == val;
    return Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 8, top: 4),
      child: FilterChip(
        label: Text(label, style: GoogleFonts.hind(fontSize: 12, color: selected ? Colors.white : muted)),
        selected: selected,
        onSelected: (_) => setState(() => _statusFilter = val),
        backgroundColor: card2,
        selectedColor: primary,
        checkmarkColor: Colors.white,
        side: const BorderSide(color: border),
      ),
    );
  }

  Widget _statusPill(String s) {
    final c = switch (s) {
      'COMPLETED' => success,
      'ONGOING' => success,
      'MATCHED' => primary,
      'REQUESTED' => primary,
      'CANCELLED' => muted,
      _ => warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
      child: Text(s, style: GoogleFonts.hind(color: c, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  String _fmtTime(String? iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('d MMM, h:mm a').format(d);
    } catch (_) { return iso; }
  }

  Future<void> _cancel(BuildContext ctx, WidgetRef ref, AutoDisposeFutureProvider<List<Map<String, dynamic>>> provider, String id) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: card,
        title: Text('Cancel ride?', style: GoogleFonts.baloo2(color: Colors.white)),
        content: Text('Ride CANCELLED mark हो जाएगा', style: GoogleFonts.hind(color: muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel ride', style: TextStyle(color: danger))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await AdminApi().cancelRide(id);
      ref.invalidate(provider);
    } catch (e) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Cancel नहीं हुआ: $e')));
    }
  }
}