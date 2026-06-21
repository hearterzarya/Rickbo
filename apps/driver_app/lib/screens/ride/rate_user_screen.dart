import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rickbo_core/rickbo_core.dart';

/// After a ride finishes, the driver briefly rates the passenger (1–5 stars).
/// Optional — driver can skip. Submitting hits POST /ratings with `by` = driverId,
/// which (for stars <= 2) lowers the user's trustScore.
class RateUserScreen extends StatefulWidget {
  final String rideId;
  const RateUserScreen({super.key, required this.rideId});

  @override
  State<RateUserScreen> createState() => _RateUserScreenState();
}

class _RateUserScreenState extends State<RateUserScreen> {
  int _stars = 5;
  final _note = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      // 'by' here is the driverId — server uses that to update user trustScore on low ratings.
      // We pass the rideId as 'by' placeholder; the safety service just stores it.
      // In Phase 5 we'll plumb the real driverId through.
      await RickboApi().rateRide(
        rideId: widget.rideId,
        stars: _stars,
        comment: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
    } catch (e) {
      if (mounted) HindiError.show(context, e);
    }
    if (!mounted) return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('सवारी रेटिंग'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('सवारी कैसी रही?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  onPressed: () => setState(() => _stars = i + 1),
                  icon: Icon(
                    i < _stars ? Icons.star : Icons.star_border,
                    color: gold,
                    size: 44,
                  ),
                )),
              ),
              const SizedBox(height: 8),
              Center(child: Text('${_stars}/5', style: TextStyle(color: muted, fontSize: 18, fontWeight: FontWeight.w700))),
              const SizedBox(height: 24),
              TextField(
                controller: _note,
                maxLines: 2,
                style: TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'नोट (वैकल्पिक)',
                  border: OutlineInputBorder(),
                ),
              ),
              const Spacer(),
              _sending
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(onPressed: _submit, child: const Text('रेटिंग भेजें')),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/'),
                  child: Text('छोड़ें', style: TextStyle(color: muted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}