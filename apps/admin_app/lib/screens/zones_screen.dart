import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rickbo_core/rickbo_core.dart' hide muted, card, ink;
import '../theme.dart';

final zonesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return AdminApi().zones();
});

class ZonesScreen extends ConsumerWidget {
  const ZonesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zones = ref.watch(zonesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zones'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(zonesProvider)),
        ],
      ),
      body: zones.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Zones load नहीं हुई: $e', style: GoogleFonts.hind(color: danger)),
          ),
        ),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final z = list[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: primary.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: Center(
                        child: Text(z['id'].toString(),
                            style: GoogleFonts.baloo2(color: primary, fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(z['name']?.toString() ?? '',
                              style: GoogleFonts.baloo2(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            '📍 ${z['lat']}, ${z['lng']}\nRadius: ${z['radius']}m',
                            style: GoogleFonts.hind(color: muted, fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}