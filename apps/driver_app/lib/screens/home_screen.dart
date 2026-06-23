import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rickbo_core/rickbo_core.dart';
import '../providers/auth_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isOnline = false;
  bool _busy = false;
  Position? _pos;
  Timer? _locTimer;
  String? _locationError;
  Map<String, dynamic>? _stats;
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Reconcile online state when returning from a completed ride. The home
    // screen disposes when the driver enters a ride, so we re-read the
    // server's truth on every entry. If the server says we're still online,
    // resume the location heartbeat without re-calling goOnline() (that
    // would 409 since we're already online). This is the post-Bug-4 fix —
    // ride complete must NOT flip the driver offline.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reconcileOnlineState());
  }

  Future<void> _reconcileOnlineState() async {
    final auth = ref.read(driverAuthProvider);
    final me = auth.me;
    if (me == null) return;
    final serverOnline = me.isOnline;
    if (serverOnline && !_isOnline) {
      // Server still has us online (e.g. we just finished a ride). Resume
      // heartbeat so we keep emitting location + accept new offers.
      setState(() => _isOnline = true);
      _locTimer?.cancel();
      _locTimer = Timer.periodic(const Duration(seconds: 12), (_) => _heartbeat());
    } else if (!serverOnline && _isOnline) {
      // Server says offline (admin suspended, etc.). Sync UI down.
      _locTimer?.cancel();
      setState(() => _isOnline = false);
    }
  }

  @override
  void dispose() {
    _locTimer?.cancel();
    _statsTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final s = await RickboApi().getDriverStats(period: 'today');
      if (mounted) setState(() => _stats = s);
    } catch (_) {}
    // Refresh stats every 30s so the count grows as rides complete.
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadStats());
  }

  Future<void> _toggleOnline() async {
    if (_isOnline) {
      // Going offline.
      try {
        await RickboApi().goOffline();
      } catch (_) {}
      _locTimer?.cancel();
      setState(() => _isOnline = false);
      return;
    }
    // Going online — requires location first.
    setState(() => _busy = true);
    try {
      _pos = await _ensureLocation();
      if (_pos == null) {
        setState(() {
          _busy = false;
          _locationError = 'GPS नहीं मिल सका — कृपया Location ऑन करें और permission दें';
        });
        return;
      }
      // 1. Send location.
      await RickboApi().postLocation(_pos!.latitude, _pos!.longitude);
      // 2. Go online.
      await RickboApi().goOnline();
      setState(() {
        _isOnline = true;
        _busy = false;
        _locationError = null;
      });
      // 3. Start periodic location.
      _locTimer?.cancel();
      _locTimer = Timer.periodic(const Duration(seconds: 12), (_) => _heartbeat());
    } catch (e) {
      final action = HindiError.actionOf(e);
      final msg = HindiError.messageOf(e);
      // Backend-rejected goOnline → show real reason + route to renewal/suspended screen.
      if (action == ErrorAction.subscriptionExpired) {
        if (!mounted) return;
        HindiError.show(context, e);
        context.push('/subscription');
      } else if (action == ErrorAction.accountSuspended) {
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('अकाउंट निलंबित'),
            content: const Text('आपका अकाउंट निलंबित है। Rickbo हेल्पलाइन पर संपर्क करें।'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('ठीक है')),
            ],
          ),
        );
      } else {
        setState(() {
          _busy = false;
          _locationError = msg;
        });
      }
    }
  }

  Future<void> _heartbeat() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
      await RickboApi().postLocation(p.latitude, p.longitude);
      // Also push via socket for faster realtime updates.
      final s = ref.read(driverSocketProvider);
      s.emit('driver:location', {'lat': p.latitude, 'lng': p.longitude});
    } catch (_) {/* don't kill offline state on hiccup */}
  }

  Future<Position?> _ensureLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _locationError = 'Location permission दें — सेटिंग्स में जाएँ';
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        _locationError = 'GPS बंद है — कृपया ON करें';
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 8),
      );
    } catch (e) {
      _locationError = 'GPS error — फिर कोशिश करें';
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(driverAuthProvider);
    final me = auth.me;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text('Rickbo Driver', style: TextStyle(fontWeight: FontWeight.w800, color: blue)),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/dev-settings')),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              if (_isOnline) {
                try { await RickboApi().goOffline(); } catch (_) {}
              }
              await ref.read(driverAuthProvider.notifier).logout();
              if (mounted) context.go('/auth/phone');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 16),
              if (me != null) _ProfileCard(me: me, isOnline: _isOnline),
              if (me != null && me.subscriptionExpired) ...[
                const SizedBox(height: 12),
                _SubscriptionBanner(me: me),
              ],
              const SizedBox(height: 16),
              // Live map showing driver location + zone context.
              if (_pos != null)
                SizedBox(
                  height: 220,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RickboMap(
                          centerLat: _pos!.latitude,
                          centerLng: _pos!.longitude,
                          zoom: 15,
                          markers: [
                            MapMarker(
                              lat: _pos!.latitude,
                              lng: _pos!.longitude,
                              icon: Icons.electric_rickshaw,
                              color: const Color(0xFFFF6B00),
                              label: 'मैं',
                            ),
                          ],
                          showZoneDots: true,
                          interactive: true,
                        ),
                      ),
                      Positioned(
                        top: 12, right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isOnline ? greenBright : card,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _isOnline ? Colors.white : muted,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isOnline ? 'LIVE' : 'OFFLINE',
                                style: TextStyle(
                                  color: _isOnline ? Colors.white : muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              _OnlineToggle(isOnline: _isOnline, busy: _busy, onTap: _toggleOnline),
              if (_locationError != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE4E4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.location_off, color: red),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_locationError!, style: TextStyle(color: ink, fontSize: 13))),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
              _StatusGrid(stats: _stats),
              const SizedBox(height: 24),
              _TodayCard(),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: tintCyan, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Dev Mode: कोई भी 10 अंकों का नंबर चलेगा। ऑटो OTP "🪄 डेव OTP भरें" से।',
                        style: TextStyle(fontSize: 12, color: ink),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final DriverModel me;
  final bool isOnline;
  const _ProfileCard({required this.me, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: line),
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: tintBlue, shape: BoxShape.circle),
            child: const Icon(Icons.person, color: blue, size: 36),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(me.name ?? 'ड्राइवर', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink)),
                const SizedBox(height: 2),
                Text((me.rickshawNumber ?? '—').toUpperCase(),
                    style: TextStyle(color: blue, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isOnline ? tintGreen : const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? green : muted,
                ),
              ),
              const SizedBox(width: 6),
              Text(isOnline ? 'ऑनलाइन' : 'ऑफलाइन',
                  style: TextStyle(color: isOnline ? green : muted, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _OnlineToggle extends StatelessWidget {
  final bool isOnline;
  final bool busy;
  final VoidCallback onTap;
  const _OnlineToggle({required this.isOnline, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isOnline ? [green, const Color(0xFF1F7A2E)] : [blue, blueDark],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: (isOnline ? green : blue).withOpacity(0.35),
              blurRadius: 24, spreadRadius: 2,
            )
          ],
        ),
        child: Center(
          child: busy
              ? const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isOnline ? Icons.pause_circle_filled : Icons.play_arrow,
                        color: Colors.white, size: 50),
                    const SizedBox(height: 6),
                    Text(isOnline ? 'ऑफलाइन जाएँ' : 'ऑनलाइन जाएँ',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StatusGrid extends StatelessWidget {
  final Map<String, dynamic>? stats;
  const _StatusGrid({required this.stats});
  @override
  Widget build(BuildContext context) {
    final rides = stats?['rides'] as int? ?? 0;
    final earnings = (stats?['earnings'] as num?)?.toInt() ?? 0;
    final rating = (stats?['ratingAvg'] as num?)?.toDouble() ?? 0.0;
    final items = [
      {'label': 'आज सफ़र', 'value': '$rides', 'icon': Icons.route, 'color': tintBlue},
      {'label': 'आज कमाई', 'value': '₹$earnings', 'icon': Icons.account_balance_wallet, 'color': tintGreen},
      {'label': 'रेटिंग', 'value': rating > 0 ? rating.toStringAsFixed(1) : '—', 'icon': Icons.star, 'color': const Color(0xFFFFF6D5)},
    ];
    return Row(
      children: items.map((m) {
        final i = items.indexOf(m);
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < items.length - 1 ? 10 : 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: m['color'] as Color, borderRadius: BorderRadius.circular(10)),
                  child: Icon(m['icon'] as IconData, color: blue, size: 18),
                ),
                const SizedBox(height: 10),
                Text(m['value'] as String, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ink)),
                Text(m['label'] as String, style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TodayCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6F49E5), Color(0xFF4327A4)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.local_offer, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('महीने की सदस्यता', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 2),
                Text('₹299 — सीधे बैंक में जमा',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.7)),
        ],
      ),
    );
  }
}

/// Red banner shown when the driver's subscription has expired.
/// Tapping routes to the renewal screen (call to support — no in-app payment in MVP).
class _SubscriptionBanner extends StatelessWidget {
  final DriverModel me;
  const _SubscriptionBanner({required this.me});

  @override
  Widget build(BuildContext context) {
    final daysAgo = me.subscriptionValidUntil != null
        ? DateTime.now().difference(me.subscriptionValidUntil!).inDays
        : 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/subscription'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('सब्सक्रिप्शन ख़त्म हो गई',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF8B0000))),
                    const SizedBox(height: 2),
                    Text(
                      daysAgo > 0
                          ? '$daysAgo दिन पहले ख़त्म हुई — रिन्यू करें'
                          : 'ऑनलाइन जाने के लिए रिन्यू करें',
                      style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.red.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
