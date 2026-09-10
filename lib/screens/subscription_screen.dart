import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isTrialActive = false;

  @override
  void initState() {
    super.initState();
    _checkTrialStatus();
  }

  void _checkTrialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isTrialActive = prefs.getBool('is_subscribed') ?? false;
    });
  }

  void _activateTrial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_subscribed', true);
    await prefs.setBool('is_trial_active', true);

    setState(() {
      _isTrialActive = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Free Trial & Test Access Activated!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("DocketFlow Test & Trial")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.card_giftcard_rounded,
              size: 72,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              "Free Test & Trial Mode",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "No payment required for test & trial mode. Enjoy full access to all DocketFlow features during testing.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        _isTrialActive
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        color: _isTrialActive ? Colors.green : Colors.blue,
                        size: 30,
                      ),
                      title: Text(
                        _isTrialActive
                            ? "Test & Trial Active"
                            : "Unlimited Inspection Tracking",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        _isTrialActive
                            ? "Full features unlocked. No payment required."
                            : "100% Private, On-Device Parsing",
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (!_isTrialActive)
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _activateTrial,
                  icon: const Icon(Icons.flash_on, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  label: const Text(
                    "Start Free Trial",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified, color: Colors.green),
                    SizedBox(width: 8),
                    Text(
                      "Trial Active — Free Access Enabled",
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

