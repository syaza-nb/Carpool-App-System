import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class TopUpScreen extends StatefulWidget {
  final String userId;
  const TopUpScreen({super.key, required this.userId});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final TextEditingController _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isGeneratingQR = false;

  // Preset quick-select amounts for easy testing
  final List<double> _presets = [10.0, 20.0, 50.0, 100.0];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  // --- SHOW SIMULATED QR PAYMENT GATEWAY ---
  void _showQRGateway(double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Center(
            child: Text(
              "Scan to Top-Up",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Scan this simulated DuitNow QR using your banking app to authorize the wallet transfer.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),

              // Simulated Malaysia National QR standard frame box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.pink.shade700, width: 3), // DuitNow pink theme accent
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      "DuitNow",
                      style: TextStyle(
                          color: Colors.pink.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.2
                      ),
                    ),
                    const SizedBox(height: 10),
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 160,
                      color: Colors.grey.shade900,
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "SECURE AFC MERCHANDISE LINK",
                      style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Amount: RM ${amount.toStringAsFixed(2)}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel Transaction", style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () {
                Navigator.pop(dialogContext); // Close QR view overlay
                _executeTopUpTransaction(amount); // Proceed to database credit pipeline
              },
              child: const Text("Paid Successfully", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- FIRESTORE DATABASE TRANSACTION PIPELINE ---
  Future<void> _executeTopUpTransaction(double topUpAmount) async {
    // Show a processing loader spinner thread
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.teal)),
      ),
    );

    try {
      final DocumentReference userRef = FirebaseFirestore.instance.collection('Users').doc(widget.userId);
      final CollectionReference transactionsRef = FirebaseFirestore.instance.collection('Transactions');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot userSnapshot = await transaction.get(userRef);

        double currentBalance = 0.00;
        if (userSnapshot.exists) {
          try {
            final rawBalance = userSnapshot.get('wallet_balance');
            if (rawBalance is num) {
              currentBalance = rawBalance.toDouble();
            }
          } catch (_) {
            currentBalance = 0.00;
          }
        }

        double newBalance = currentBalance + topUpAmount;

        // 1. Update the wallet balance field on the user profile document snapshot
        transaction.update(userRef, {
          'wallet_balance': double.parse(newBalance.toStringAsFixed(2)),
        });

        // 2. Generate a structural transaction historical row tracking audit entry
        DocumentReference newTxnRef = transactionsRef.doc();
        transaction.set(newTxnRef, {
          'transaction_id': newTxnRef.id,
          'user_id': widget.userId,
          'type': 'Credit',
          'amount': topUpAmount,
          'description': 'E-Wallet Top-Up via Gateway QR Code',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      Navigator.pop(context); // Dismiss loading overlay panel spinner

      // Display beautiful success alert confirmation sheet box summary
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Successfully added RM ${topUpAmount.toStringAsFixed(2)} to your balance ledger!"),
          backgroundColor: Colors.green,
        ),
      );

      _amountController.clear();
      Navigator.pop(context); // Return back seamlessly out to parent workspace balance board
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Kill active lingering loader task thread
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Top-up transactional pipeline failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Wallet Top-Up"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Reload Account Balance",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
                const Text(
                  "Enter custom funds value or select a swift package amount configuration.",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 25),

                // ================= CUSTOM INPUT FIELD AMOUNT =================
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
                  decoration: const InputDecoration(
                    prefixText: "RM ",
                    prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.teal),
                    labelText: "Top-Up Amount",
                    labelStyle: TextStyle(fontSize: 14, color: Colors.grey),
                    border: OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.teal, width: 2)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Please enter a valid monetary value.";
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return "Amount must be greater than RM 0.00";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ================= QUICK CHIP PRESET PACKAGES =================
                const Text(
                  "Quick Selection Shortcuts",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _presets.map((preset) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ActionChip(
                          backgroundColor: Colors.teal.withOpacity(0.05),
                          side: const BorderSide(color: Colors.teal, width: 0.5),
                          label: Text(
                            "RM ${preset.toStringAsFixed(0)}",
                            style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          onPressed: () {
                            setState(() {
                              _amountController.text = preset.toStringAsFixed(2);
                            });
                          },
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 40),

                // ================= TRIGGER GATEWAY ACTION BUTTON =================
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.qr_code_rounded),
                    label: const Text(
                      "GENERATE DEPOSIT QR LINK",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final double selectedValue = double.parse(_amountController.text.trim());
                        _showQRGateway(selectedValue);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}