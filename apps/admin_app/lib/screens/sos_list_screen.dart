import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:rickbo_core/rickbo_core.dart' hide muted, card, ink;
import '../theme.dart';

class SosListScreen extends ConsumerStatefulWidget {
  const SosListScreen({super.key});
  @override
  ConsumerState<SosListScreen> createState() => _SosListScreenState();
}

class _SosListScreenState extends ConsumerState<SosListScreen> {
  bool? _resolved; // null = all
  late final sosProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
    return AdminApi().sos(resolved: _resolved);
  });

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(sosProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS Events'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(sosProvider)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              const SizedBox(width: 12),
              _filter('Open', false),
              const SizedBox(width: 6),
              _filter('Resolved', true),
              const SizedBox(width: 6),
              _filter('All', null),
            ],
          ),
        ),
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('SOS load नहीं हुई: $e', style: GoogleFonts.hind(color: danger)),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield, color: success, size: 64),
                    const SizedBox(height: 12),
                    Text('कोई SOS नहीं', style: GoogleFonts.baloo2(color: Colors.white, fontSize: 18)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(sosProvider);
              await ref.read(sosProvider.future);
            },
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final s = items[i];
                final resolved = s['resolved'] == true;
                final raisedBy = s['raisedBy']?.toString() ?? '?';
                final ride = s['ride'] as Map?;
                final user = ride?['user'] as Map?;
                final driver = ride?['driver'] as Map?;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: resolved ? muted.withValues(alpha: 0.2) : danger.withValues(alpha: 0.2),
                    child: Icon(resolved ? Icons.check : Icons.emergency,
                        color: resolved ? muted : danger),
                  ),
                  title: Text(
                    'SOS — ${raisedBy.toLowerCase()}',
                    style: GoogleFonts.baloo2(
                      color: resolved ? muted : Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '👤 ${user?['phone'] ?? '?'}\n'
                      '🛺 ${driver?['phone'] ?? 'no driver'}\n'
                      '📍 ${_fmtNum(s['lat'])}, ${_fmtNum(s['lng'])}\n'
                      '${_fmtTime(s['createdAt']?.toString())}',
                      style: GoogleFonts.hind(color: muted, fontSize: 12, height: 1.3),
                    ),
                  ),
                  isThreeLine: true,
                  trailing: resolved
                      ? null
                      : ElevatedButton(
                          onPressed: () => _resolve(ctx, ref, sosProvider, s['id'] as String),
                          child: const Text('Resolve'),
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _filter(String label, bool? val) {
    final selected = _resolved == val;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: FilterChip(
        label: Text(label, style: GoogleFonts.hind(fontSize: 12, color: selected ? Colors.white : muted)),
        selected: selected,
        onSelected: (_) => setState(() => _resolved = val),
        backgroundColor: card2,
        selectedColor: primary,
        checkmarkColor: Colors.white,
        side: const BorderSide(color: border),
      ),
    );
  }

  String _fmtTime(String? iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.parse(iso).toLocal();
      return DateFormat('d MMM, h:mm a').format(d);
    } catch (_) { return iso; }
  }

  String _fmtNum(dynamic v) {
    if (v == null) return '-';
    final n = (v as num).toDouble();
    return n.toStringAsFixed(4);
  }

  Future<void> _resolve(BuildContext ctx, WidgetRef ref, AutoDisposeFutureProvider<List<Map<String, dynamic>>> provider, String id) async {
    final notes = await showDialog<String?>(
      context: ctx,
      builder: (_) => _NotesDialog(),
    );
    try {
      await AdminApi().resolveSos(id, notes: notes);
      ref.invalidate(provider);
    } catch (e) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Resolve नहीं हुआ: $e')));
    }
  }
}

class _NotesDialog extends StatefulWidget {
  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: card,
      title: Text('Resolve SOS', style: GoogleFonts.baloo2(color: Colors.white)),
      content: TextField(
        controller: _ctrl,
        style: GoogleFonts.hind(color: Colors.white),
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'Notes (optional)'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, _ctrl.text), child: const Text('Mark Resolved')),
      ],
    );
  }
}