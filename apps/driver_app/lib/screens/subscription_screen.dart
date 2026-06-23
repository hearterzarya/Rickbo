import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rickbo_core/rickbo_core.dart';

import '../providers/auth_provider.dart';

/// Subscription / renewal screen for drivers whose subscription is expired or
/// about to expire. Driver calls support to renew — there's no online payment
/// in MVP (per CLAUDE.md). Shows the days remaining from the driver profile.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(driverAuthProvider).me;
    final daysLeft = me?.subscriptionDaysLeft;
    final expired = me?.subscriptionExpired ?? false;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        title: const Text('सब्सक्रिप्शन', style: TextStyle(fontWeight: FontWeight.w800, color: blue)),
        iconTheme: const IconThemeData(color: blue),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: expired ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      expired ? Icons.error_outline : Icons.verified,
                      color: expired ? Colors.red.shade700 : Colors.green.shade700,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expired
                                ? 'सब्सक्रिप्शन ख़त्म हो गई'
                                : (daysLeft != null
                                    ? '$daysLeft दिन बचे हैं'
                                    : 'सब्सक्रिप्शन चालू है'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            expired
                                ? 'ऑनलाइन जाने के लिए सब्सक्रिप्शन रिन्यू करें'
                                : 'कोई कमीशन नहीं — पक्का किराया आपको',
                            style: const TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const _BulletRow(
                icon: Icons.directions_car,
                title: 'पूरी रिक्शा बुकिंग',
                subtitle: 'जितनी सवारी उतना किराया — बस ऐप खोलो',
              ),
              const _BulletRow(
                icon: Icons.share_location,
                title: 'साझा सवारी',
                subtitle: 'एक ही रास्ते पर 2-3 सवारी',
              ),
              const _BulletRow(
                icon: Icons.payments,
                title: 'मासिक सब्सक्रिप्शन',
                subtitle: 'रोज़ का कमीशन नहीं',
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('रिन्यू कैसे करें'),
                      content: const Text(
                        'रिन्यू के लिए Rickbo हेल्पलाइन पर कॉल करें:\n\n'
                        '📞 98765-43210\n\n'
                        'या दुकानदार से संपर्क करें — 5 मिनट में अकाउंट चालू।',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('ठीक है'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.phone),
                label: const Text('रिन्यू करने के लिए कॉल करें'),
                style: FilledButton.styleFrom(
                  backgroundColor: blue,
                  minimumSize: const Size.fromHeight(56),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _BulletRow({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: tintBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: blue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
