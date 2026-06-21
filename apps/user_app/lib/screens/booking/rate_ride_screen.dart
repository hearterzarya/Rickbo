import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rickbo_core/rickbo_core.dart';

class RateRideScreen extends StatefulWidget {
  final String rideId;
  final String driverId;
  const RateRideScreen({super.key, required this.rideId, this.driverId = ''});

  @override
  State<RateRideScreen> createState() => _RateRideScreenState();
}

class _RateRideScreenState extends State<RateRideScreen> {
  int _stars = 5;
  final _commentCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await RickboApi().rateRide(
        rideId: widget.rideId,
        stars: _stars,
        comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
      );
    } catch (e) {
      if (mounted) HindiError.show(context, e);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('धन्यवाद! आपकी रेटिंग सेव हो गई।')),
    );
    if (mounted) context.go('/');
  }

  void _openComplaintSheet() {
    final reasonCtrl = TextEditingController();
    String selected = 'ड्राइवर ने आने से मना कर दिया';
    final reasons = [
      'ड्राइवर ने आने से मना कर दिया',
      'बहुत ज़्यादा किराया माँगा',
      'गाड़ी साफ़ नहीं थी',
      'सफ़र के दौरान बदतमीज़ी',
      'सुरक्षा से जुड़ी कोई बात',
      'अन्य',
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (ctx, setSheet) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('शिकायत दर्ज करें', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ink)),
                const SizedBox(height: 8),
                Text('ड्राइवर की आईडी इस सफ़र से जुड़ी है — आपकी शिकायत सीधे कंट्रोल रूम को जाएगी।',
                    style: TextStyle(color: muted, fontSize: 13)),
                const SizedBox(height: 16),
                ...reasons.map((r) => RadioListTile<String>(
                      title: Text(r, style: TextStyle(fontSize: 16)),
                      value: r,
                      groupValue: selected,
                      onChanged: (v) => setSheet(() => selected = v ?? selected),
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  style: TextStyle(fontSize: 15),
                  decoration: const InputDecoration(
                    labelText: 'और कुछ कहना है? (वैकल्पिक)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: red, foregroundColor: Colors.white),
                    onPressed: () async {
                      // We don't have against id here easily — use rideId as 'against' marker.
                      // Backend auto-flags driver by 'against' (which equals driverId when sent from rate flow).
                      // For simplicity, we send the rideId; the safety service flag logic uses
                      // openCount against the string id. In Phase 5 we'll pass the real driver id.
                      try {
                        await RickboApi().raiseComplaint(
                          rideId: widget.rideId,
                          // Real driverId from previous screen (passed via router extra) —
                          // backend uses it to count + auto-suspend repeat offenders.
                          // If empty (Phase 2 fallback), backend still stores the complaint
                          // but auto-suspend logic won't match.
                          against: widget.driverId.isNotEmpty ? widget.driverId : widget.rideId,
                          reason: selected + (reasonCtrl.text.trim().isNotEmpty ? ' — ${reasonCtrl.text.trim()}' : ''),
                          severity: 2,
                        );
                      } catch (e) {
                        if (mounted) HindiError.show(context, e);
                      }
                      if (mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('शिकायत दर्ज हो गई — धन्यवाद')),
                        );
                      }
                    },
                    child: const Text('शिकायत भेजें'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: const Text('रेटिंग दें'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text('सफ़र कैसा रहा?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ink)),
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
                controller: _commentCtrl,
                maxLines: 3,
                style: TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'कुछ कहना है? (वैकल्पिक)',
                  border: OutlineInputBorder(),
                ),
              ),
              const Spacer(),
              _sending
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(onPressed: _submit, child: const Text('भेजें')),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/'),
                  child: Text('अभी नहीं', style: TextStyle(color: muted)),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton.icon(
                  onPressed: _openComplaintSheet,
                  icon: const Icon(Icons.report_problem_outlined, color: red, size: 18),
                  label: Text('शिकायत दर्ज करें', style: TextStyle(color: red, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
