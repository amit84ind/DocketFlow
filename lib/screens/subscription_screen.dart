import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final TextEditingController _utrController = TextEditingController();
  final String upiId = "yourname@upi"; // Replace with your static UPI ID
  final String whatsappNumber = "+919876543210"; // Replace with your WhatsApp number

  void _activateSubscription() async {
    final utr = _utrController.text.trim();
    if (utr.length != 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid 12-digit UTR/UPI Ref ID")),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_subscribed', true);
    await prefs.setString('utr_submitted', utr);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Access Activated! Verification in progress.")),
      );
      Navigator.pop(context);
    }
  }

  void _openWhatsApp() async {
    final url = Uri.parse("https://wa.me/$whatsappNumber?text=Hi%2C%20I%20have%20paid%20Rs.100%20for%20DocketFlow.%20UTR:%20${_utrController.text}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final upiUri = "upi://pay?pa=$upiId&pn=DocketFlow&am=100&cu=INR&tn=Annual_Pass";

    return Scaffold(
      appBar: AppBar(title: const Text("DocketFlow Annual Pass")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              "₹100 / Year",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
            const Text("Unlimited On-Device Inspection Tracking • 100% Private"),
            const SizedBox(height: 20),
            Center(
              child: QrImageView(
                data: upiUri,
                version: QrVersions.auto,
                size: 220.0,
              ),
            ),
            const SizedBox(height: 10),
            Text("Scan via GPay / PhonePe / Paytm", style: TextStyle(color: Colors.grey.shade600)),
            const Divider(height: 40),
            TextField(
              controller: _utrController,
              keyboardType: TextInputType.number,
              maxLength: 12,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: "12-Digit UTR / Transaction Ref No.",
                hintText: "e.g. 423987123456",
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _activateSubscription,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: const Text("Submit & Activate", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _openWhatsApp,
              icon: const Icon(Icons.chat, color: Colors.green),
              label: const Text("Verify on WhatsApp"),
            )
          ],
        ),
      ),
    );
  }
}
