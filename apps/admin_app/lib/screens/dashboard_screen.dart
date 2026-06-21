import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rickbo_core/rickbo_core.dart' hide muted, card, ink;
import '../providers/auth_provider.dart';
import '../theme.dart';

final statsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = AdminApi();
  return api.stats();
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      ref.invalidate(statsProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rickbo — Control Room'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(statsProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(statsProvider);
          await ref.read(statsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            stats.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => _ErrorBox(message: 'Stats load नहीं हुई: $e'),
              data: (s) => _StatsGrid(s: s),
            ),
            const SizedBox(height: 20),
            Text('Operations',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _NavTile(icon: Icons.people, label: 'Users', sub: 'सभी यात्री', onTap: () => context.push('/users')),
            _NavTile(icon: Icons.electric_rickshaw, label: 'Drivers', sub: 'Active, suspended, banned', onTap: () => context.push('/drivers')),
            _NavTile(icon: Icons.directions_car, label: 'Rides', sub: 'Live + history', onTap: () => context.push('/rides')),
            _NavTile(icon: Icons.emergency, label: 'SOS Events', sub: 'Unresolved first', onTap: () => context.push('/sos')),
            _NavTile(icon: Icons.map, label: 'Zones', sub: 'A / B / C / D / E', onTap: () => context.push('/zones')),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> s;
  const _StatsGrid({required this.s});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _StatCard(label: 'Users', value: '${s['users'] ?? 0}', icon: Icons.people, color: primary),
        _StatCard(label: 'Drivers', value: '${s['drivers'] ?? 0}', sub: '${s['activeDrivers'] ?? 0} active', icon: Icons.electric_rickshaw, color: success),
        _StatCard(label: 'Rides Today', value: '${s['ridesToday'] ?? 0}', icon: Icons.directions_car, color: warning),
        _StatCard(
          label: 'Open SOS',
          value: '${s['openSos'] ?? 0}',
          icon: Icons.emergency,
          color: (s['openSos'] ?? 0) > 0 ? danger : muted,
          alert: (s['openSos'] ?? 0) > 0,
        ),
        _StatCard(label: 'Ongoing Rides', value: '${s['ongoingRides'] ?? 0}', icon: Icons.timelapse, color: primary),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color color;
  final bool alert;
  const _StatCard({required this.label, required this.value, this.sub, required this.icon, required this.color, this.alert = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        decoration: alert
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: danger, width: 1.5),
              )
            : null,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: TextStyle(color: muted, fontSize: 12)),
                  Text(value, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  if (sub != null) Text(sub!, style: TextStyle(color: muted, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  const _NavTile({required this.icon, required this.label, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: primary.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: Icon(icon, color: primary, size: 22),
        ),
        title: Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        subtitle: Text(sub, style: TextStyle(color: muted, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: muted),
        onTap: onTap,
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
      child: Text(message, style: TextStyle(color: danger, fontSize: 13)),
    );
  }
}