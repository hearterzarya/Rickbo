import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rickbo_core/rickbo_core.dart';
import '../providers/auth_provider.dart';
import '../providers/ride_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<Map<String, dynamic>> _zones = [];
  bool _loading = false;
  double? _pickupLat;
  double? _pickupLng;

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  Future<void> _loadZones() async {
    try {
      final zones = await RickboApi().getZones();
      if (mounted) setState(() => _zones = zones);
    } catch (_) { /* will show empty state */ }
  }

  Future<void> _book() async {
    setState(() => _loading = true);
    try {
      // 1. Get GPS (or fall back to zone A center for emulator w/o GPS).
      final pos = await _safeLocation();
      _pickupLat = pos?.latitude ?? 29.6039;
      _pickupLng = pos?.longitude ?? 78.3365;
      // 2. Resolve pickup zone.
      final fromZone = resolveZone(_pickupLat!, _pickupLng!);
      // 3. Ask user to pick destination zone.
      if (!mounted) return;
      final toZone = await _showZonePicker();
      if (toZone == null) {
        setState(() => _loading = false);
        return;
      }
      // 4. Show fare confirm sheet.
      if (!mounted) return;
      final sheet = await _showFareSheet(fromZone, toZone);
      if (sheet == null) {
        setState(() => _loading = false);
        return;
      }
      final pax = sheet['pax'] as int;
      final mode = (sheet['mode'] as String).toUpperCase();
      // 5. Create the ride → matching starts server-side.
      final ride = await RickboApi().createRide(
        mode: mode,
        fromZone: fromZone,
        toZone: toZone,
        pickupLat: _pickupLat!,
        pickupLng: _pickupLng!,
        passengerCount: pax,
      );
      ref.read(activeRideProvider.notifier).start(ActiveRide(
            rideId: ride.id,
            status: ride.status,
            mode: ride.mode,
            fare: ride.fare,
            fromZone: fromZone,
            toZone: toZone,
            pickupLat: _pickupLat,
            pickupLng: _pickupLng,
            shareToken: ride.shareToken,
            shareGroupId: ride.shareGroupId,
            shareDeadline: ride.shareDeadline,
          ));
      // 6. Hook up socket listeners for this ride.
      _connectSocketForUser(ride.id);
      if (!mounted) return;
      context.push('/booking/searching', extra: {'rideId': ride.id});
    } catch (e) {
      if (mounted) _toast('बुकिंग नहीं हो सकी — दोबारा कोशिश करें');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Position?> _safeLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 6),
      );
    } catch (_) {
      return null;
    }
  }

  void _connectSocketForUser(String rideId) {
    final api = ApiClient();
    api.getBaseUrl().then((base) async {
      final token = await api.getToken();
      if (token == null) return;
      final s = ref.read(socketProvider);
      await s.connect(baseUrl: base, token: token);
      // Join the ride room on the server. Backend handler ride:join (Phase 1.A)
      // subscribes this socket to ride:${rideId} so it receives driver:location.
      Future.delayed(const Duration(milliseconds: 300), () {
        s.emit('ride:join', {'rideId': rideId});
      });
    });
  }

  Future<String?> _showZonePicker() async {
    String? selected;
    await showModalBottomSheet(
      context: context,
      backgroundColor: card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text('कहाँ जाना है?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 4),
              Text('एक जगह चुनें', style: TextStyle(color: muted, fontSize: 14)),
              const SizedBox(height: 20),
              ..._zones.map((z) => InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      selected = z['id'] as String;
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: line),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: tintBlue, borderRadius: BorderRadius.circular(12)),
                            child: Center(child: Text(z['id'] as String,
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: blue))),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Text(z['name'] as String,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: ink))),
                          const Icon(Icons.chevron_right, color: muted),
                        ],
                      ),
                    ),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    return selected;
  }

  Future<Map<String, dynamic>?> _showFareSheet(String from, String to) async {
    final isNight = isNightTime(DateTime.now());
    final fromName = _zones.firstWhere((z) => z['id'] == from, orElse: () => _zones.first)['name'] as String;
    final toName = _zones.firstWhere((z) => z['id'] == to, orElse: () => _zones.first)['name'] as String;
    String mode = 'reserve'; // 'reserve' | 'share'
    int pax = 1;
    int fare = getFare(from, to, mode, isNight);

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(fromName, style: TextStyle(color: muted, fontSize: 14)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.circle, color: greenBright, size: 14),
                    const SizedBox(width: 10),
                    Expanded(child: Container(height: 2, color: line)),
                    const SizedBox(width: 10),
                    const Icon(Icons.location_on, color: red, size: 22),
                  ],
                ),
                const SizedBox(height: 6),
                Text(toName, style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                // Phase 4: RESERVE vs SHARE mode toggle
                Row(
                  children: [
                    Expanded(
                      child: _ModeChip(
                        label: 'पूरी रिक्शा',
                        subtitle: '1–4 यात्री',
                        icon: Icons.electric_rickshaw,
                        selected: mode == 'reserve',
                        onTap: () => setSheet(() {
                          mode = 'reserve';
                          fare = getFare(from, to, mode, isNight);
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ModeChip(
                        label: 'साझा सवारी',
                        subtitle: 'सस्ती, 2 min इंतज़ार',
                        icon: Icons.people,
                        selected: mode == 'share',
                        onTap: () => setSheet(() {
                          mode = 'share';
                          fare = getFare(from, to, mode, isNight);
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [blue, blueDark],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [blueShadow()],
                  ),
                  child: Row(
                    children: [
                      Icon(mode == 'share' ? Icons.people : Icons.electric_rickshaw, color: Colors.white, size: 32),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mode == 'share' ? 'साझा सवारी — प्रति सवारी' : 'पूरी रिक्शा',
                                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                            Text('₹$fare पक्का किराया',
                                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                            if (isNight)
                              Text('रात का +₹5 जुड़ा है',
                                  style: TextStyle(color: const Color(0xFFFFE4A0), fontSize: 12)),
                            if (mode == 'share')
                              Text('अगर कोई न मिले तो "अकेले ₹25" चुनें',
                                  style: TextStyle(color: const Color(0xFFFFE4A0), fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (mode == 'reserve')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('यात्री:', style: TextStyle(color: muted, fontSize: 14)),
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: pax > 1 ? () => setSheet(() => pax--) : null,
                            icon: const Icon(Icons.remove_circle_outline, color: blue),
                          ),
                          Text('$pax', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ink)),
                          // 4-pax is the legal max per Section 3 of CLAUDE.md.
                          // Tapping + at pax==4 shows a Hindi toast suggesting
                          // booking a 2nd rickshaw instead of silently blocking.
                          IconButton(
                            onPressed: () {
                              if (pax >= 4) {
                                setSheet(() {});
                                _toast('4 से ज़्यादा नहीं — दूसरी रिक्शा बुक करें');
                              } else {
                                setSheet(() => pax++);
                              }
                            },
                            icon: const Icon(Icons.add_circle, color: blue),
                          ),
                          const Spacer(),
                          Text('(1–4)', style: TextStyle(color: muted, fontSize: 12)),
                        ],
                      ),
                      if (pax >= 4)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, left: 56),
                          child: Text(
                            '4 से ज़्यादा यात्री हों तो दूसरी रिक्शा बुक करें',
                            style: TextStyle(color: red, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: greenBright.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: greenBright.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: greenBright, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '2 मिनट इंतज़ार करेंगे। कोई और सवारी मिले तो ₹$fare देने होंगे। नहीं मिले तो "अकेले ₹25" चुन सकते हैं।',
                            style: TextStyle(color: ink, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, {'pax': pax, 'mode': mode}),
                  child: Text('बुक करें  →  ₹$fare'),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: Text('रद्द करें', style: TextStyle(color: muted)),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rickbo', style: TextStyle(fontWeight: FontWeight.w800, color: blue)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Dev Settings',
            onPressed: () => context.push('/dev-settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'लॉगआउट',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/auth/phone');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('नमस्ते! 👋', style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 4),
              Text('कहाँ चलें?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 24),
              _Hero(onTap: _loading ? null : _book, loading: _loading),
              const SizedBox(height: 16),
              const _TrustStrip(),
              const SizedBox(height: 24),
              Text('जल्दी जाने की जगहें',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink)),
              const SizedBox(height: 12),
              const _QuickChips(),
              const SizedBox(height: 24),
              _DebugCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;
  const _Hero({required this.onTap, required this.loading});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [blue, blueDark],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [blueShadow(opacity: 0.35, blurRadius: 30)],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10, bottom: -10,
              child: Icon(Icons.electric_rickshaw,
                  size: 130, color: Colors.white.withOpacity(0.10)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🛺  रिक्शा बुलाओ',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 6),
                Text('पक्का किराया • सुरक्षित सफ़र',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(loading ? 'रुकें...' : 'अभी बुक करो  →',
                          style: TextStyle(color: blue, fontSize: 14, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        _Pill('वेरिफाइड ड्राइवर', Icons.verified_user_outlined, tintBlue),
        _Pill('लाइव लोकेशन', Icons.location_on_outlined, tintCyan),
        _Pill('SOS मदद', Icons.sos_outlined, Color(0xFFFFE4E4)),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  const _Pill(this.label, this.icon, this.bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ink),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ink)),
        ],
      ),
    );
  }
}

class _QuickChips extends StatelessWidget {
  const _QuickChips();
  @override
  Widget build(BuildContext context) {
    final items = [
      {'id': 'A', 'icon': Icons.train, 'label': 'स्टेशन'},
      {'id': 'B', 'icon': Icons.local_hospital, 'label': 'अस्पताल'},
      {'id': 'C', 'icon': Icons.storefront, 'label': 'बाज़ार'},
      {'id': 'D', 'icon': Icons.account_balance, 'label': 'कोर्ट'},
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: items
          .map((m) => Container(
                width: 78, height: 78,
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: tintBlue, borderRadius: BorderRadius.circular(10)),
                      child: Icon(m['icon'] as IconData, color: blue, size: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(m['label'] as String, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ink)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _DebugCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: tintCyan, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Dev Mode: कोई भी 10 अंकों का नंबर डालें — backend 6 अंकों का OTP देगा। '
              'OTP स्क्रीन पर "🪄 डेव OTP भरें" से ऑटो-फिल।',
              style: TextStyle(fontSize: 12, color: ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? blue : Colors.white,
          border: Border.all(color: selected ? blue : line, width: 2),
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected ? [blueShadow()] : [],
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.white : ink, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14,
                          color: selected ? Colors.white : ink)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: selected ? Colors.white70 : muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}