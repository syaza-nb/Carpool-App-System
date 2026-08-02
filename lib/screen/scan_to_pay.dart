import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class ScanToPayScreen extends StatefulWidget {
  final String userId;
  const ScanToPayScreen({super.key, required this.userId});

  @override
  State<ScanToPayScreen> createState() => _ScanToPayScreenState();
}

class _ScanToPayScreenState extends State<ScanToPayScreen> with SingleTickerProviderStateMixin {
  bool _isProcessing = false;
  late AnimationController _animationController;
  final MobileScannerController _cameraController = MobileScannerController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  // --- REAL FIRESTORE TRANSACTION PIPELINE FROM QR DATA ---
  Future<void> _processQRTransaction(String rawQrData) async {
    Map<String, dynamic> qrData;
    try {
      qrData = jsonDecode(rawQrData);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid QR Format")));
      return;
    }

    // 2. Extract values dynamically
    final String scannedDriverId = qrData['driver_id'];
    final double splitFare = (qrData['amount_per_pax'] as num).toDouble();
    // Assuming you added 'destination' to your BookingScreen map:
    final String destinationName = qrData['destination'] ?? "Carpool Trip";

    // 3. Now continue with your existing processing logic
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    _cameraController.stop();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.teal)),
      ),
    );

    try {
      final DocumentReference passengerRef = FirebaseFirestore.instance.collection('Users').doc(widget.userId);
      final DocumentReference driverRef = FirebaseFirestore.instance.collection('Users').doc(scannedDriverId);
      final CollectionReference transactionsRef = FirebaseFirestore.instance.collection('Transactions');
      final CollectionReference ridesRef = FirebaseFirestore.instance.collection('Rides');

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot passengerSnapshot = await transaction.get(passengerRef);
        DocumentSnapshot driverSnapshot = await transaction.get(driverRef);

        if (!passengerSnapshot.exists) {
          throw Exception("Your profile record could not be located.");
        }

        double passengerBalance = 0.00;
        final rawPassengerBalance = passengerSnapshot.get('wallet_balance');
        if (rawPassengerBalance is num) {
          passengerBalance = rawPassengerBalance.toDouble();
        }

        if (passengerBalance < splitFare) {
          throw Exception("INSUFFICIENT_FUNDS");
        }

        double driverBalance = 0.00;
        if (driverSnapshot.exists) {
          final rawDriverBalance = driverSnapshot.get('wallet_balance');
          if (rawDriverBalance is num) {
            driverBalance = rawDriverBalance.toDouble();
          }
        }

        double newPassengerBalance = passengerBalance - splitFare;
        double newDriverBalance = driverBalance + splitFare;

        // Debit passenger, credit driver
        transaction.update(passengerRef, {'wallet_balance': double.parse(newPassengerBalance.toStringAsFixed(2))});

        if (driverSnapshot.exists) {
          transaction.update(driverRef, {'wallet_balance': double.parse(newDriverBalance.toStringAsFixed(2))});
        } else {
          transaction.set(driverRef, {'wallet_balance': double.parse(newDriverBalance.toStringAsFixed(2))}, SetOptions(merge: true));
        }

        // Log Ride
        DocumentReference newRideRef = ridesRef.doc();
        transaction.set(newRideRef, {
          'ride_id': newRideRef.id,
          'passenger_id': widget.userId,
          'driver_id': scannedDriverId,
          'pickup_location': 'Current Shared Point',
          'destination': destinationName,
          'fare_amount': splitFare,
          'status': 'Paid',
          'pickup_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Audit trails
        DocumentReference pTxnRef = transactionsRef.doc();
        transaction.set(pTxnRef, {
          'transaction_id': pTxnRef.id,
          'user_id': widget.userId,
          'type': 'Debit',
          'amount': splitFare,
          'description': 'Paid Carpool Share via Live QR Scanner',
          'timestamp': FieldValue.serverTimestamp(),
        });

        DocumentReference dTxnRef = transactionsRef.doc();
        transaction.set(dTxnRef, {
          'transaction_id': dTxnRef.id,
          'user_id': scannedDriverId,
          'type': 'Credit',
          'amount': splitFare,
          'description': 'Received Carpool Share from Scan',
          'timestamp': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      Navigator.pop(context); // Dismiss spinner
      _showReceiptDialog(destinationName, splitFare);

    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss spinner

      if (e.toString().contains("INSUFFICIENT_FUNDS")) {
        _showFailureDialog("Insufficient Balance", "You need at least RM ${splitFare.toStringAsFixed(2)} to pay for this split.");
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Processing error: $e")));
        _resumeScanning();
      }
    }
  }

  void _resumeScanning() {
    setState(() {
      _isProcessing = false;
    });
    _cameraController.start();
  }

  void _showReceiptDialog(String dest, double fare) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 30),
            SizedBox(width: 10),
            Text("Payment Success", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Your payment has been successfully processed.", style: TextStyle(fontSize: 13, color: Colors.grey)),
            const Divider(height: 24),
            Text("Destination: $dest", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Amount Settled:", style: TextStyle(fontSize: 13)),
                Text("RM ${fare.toStringAsFixed(2)}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.teal)),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Finish", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  void _showFailureDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resumeScanning();
            },
            child: const Text("Try Again", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Scan Friend's QR"),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // ================= LIVE CAMERA HARDWARE INTERFACE =================
          MobileScanner(
            controller: _cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty && !_isProcessing) {
                final String? qrData = barcodes.first.rawValue;
                if (qrData != null && qrData.trim().isNotEmpty) {
                  // The text hidden inside your friend's QR code becomes the driver_id
                  _processQRTransaction(qrData.trim());
                }
              }
            },
          ),

          // ================= GRAPHICAL HUD OVERLAY =================
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Align the driver's phone QR inside the frame",
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 30),

                // Translucent scanning frame target box
                Stack(
                  children: [
                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.teal, width: 3),
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.transparent,
                      ),
                    ),
                    // Animated scanning laser line
                    if (!_isProcessing)
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Positioned(
                            top: _animationController.value * 240 + 10,
                            left: 10,
                            right: 10,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                  color: Colors.teal,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.teal.withOpacity(0.8),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    )
                                  ]
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}