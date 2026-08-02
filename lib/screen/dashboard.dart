import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'booking.dart';
import 'topup.dart';
import 'scan_to_pay.dart';
import 'transaction_history.dart';
import 'create_ride.dart';
import 'ride_details.dart';
import 'my_ride_list.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const CarPoolApp());
}

class CarPoolApp extends StatelessWidget {
  const CarPoolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CarPool AFC System',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: const RegistrationScreen(),
    );
  }
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  String _selectedRole = 'Passenger';

  Future<void> _registerUser() async {
    if (_nameController.text.isEmpty || _idController.text.isEmpty) return;

    await FirebaseFirestore.instance.collection('Users').doc(_idController.text).set({
      'name': _nameController.text,
      'role': _selectedRole,
      'wallet_balance': 0.0,
      'status': 'Active',
      'created_at': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardScreen(userId: _idController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CarPool Sign-Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Full Name')),
            TextField(controller: _idController, decoration: const InputDecoration(labelText: 'Student/Staff ID')),
            const SizedBox(height: 20),
            const Text("Register as:"),
            RadioListTile(
              title: const Text('Passenger'),
              value: 'Passenger',
              groupValue: _selectedRole,
              onChanged: (v) => setState(() => _selectedRole = v!),
            ),
            RadioListTile(
              title: const Text('Driver'),
              value: 'Driver',
              groupValue: _selectedRole,
              onChanged: (v) => setState(() => _selectedRole = v!),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _registerUser, child: const Text('Register & Enter App')),
          ],
        ),
      ),
    );
  }
}

// Make sure these imports are at the top of the file if Dashboard is in a separate screen
// import 'booking.dart';
// import 'topup.dart';

class DashboardScreen extends StatelessWidget {
  final String userId;
  const DashboardScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('CarPool Dashboard'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,

        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // This clears the navigation stack and sends them back to Registration
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const RegistrationScreen()),
                    (route) => false,
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Users').doc(userId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          var userData = snapshot.data!.data() as Map<String, dynamic>;
          print("DEBUG: Raw Firestore data for $userId is: $userData");
          double balance = (userData['wallet_balance'] ?? 0.0).toDouble();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // 1. Profile Summary Card
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.person, color: Colors.white)),
                    title: Text(userData['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("ID: $userId"),
                    trailing: Chip(label: Text(userData['role'], style: const TextStyle(color: Colors.teal))),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Wallet Balance Card
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Text("E-Wallet Balance", style: TextStyle(color: Colors.grey, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text("RM ${balance.toStringAsFixed(2)}",
                            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.teal)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Role-Specific Action Cards
                if (userData['role'] == 'Passenger') ...[
                  _buildActionCard(context, "Top Up Wallet", Icons.account_balance_wallet, Colors.blue, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => TopUpScreen(userId: userId)));
                  }),
                  _buildActionCard(context, "SCAN TO PAY", Icons.qr_code_scanner, Colors.teal, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => ScanToPayScreen(userId: userId)));
                  }),
                  _buildActionCard(context, "View Transaction History", Icons.history, Colors.indigo, () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => TransactionHistoryScreen(userId: userId))
                    );
                  }),

                  _buildAvailableRides(userId),
                  _buildActionCard(context, "My Bookings", Icons.bookmark, Colors.purple, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => MyBookingsList(userId: userId)),
                    );
                  }),

                ] else if (userData['role'] == 'Driver') ...[
                  _buildActionCard(context, "Create New Ride", Icons.add_circle, Colors.green, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CreateRideScreen(userId: userId)),
                    );
                  }),
                  _buildActionCard(context, "Calculate Fare Ride", Icons.directions_car, Colors.orange, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => BookingScreen(userId: userId)));
                  }),
                  _buildActionCard(context, "Top Up Wallet", Icons.account_balance_wallet, Colors.blue, () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => TopUpScreen(userId: userId)));
                  }),
                  _buildActionCard(context, "My Posted Rides", Icons.car_crash, Colors.blue, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MyRidesListScreen(userId: userId),
                      ),
                    );
                  }),
                  _buildActionCard(context, "View Transaction History", Icons.history, Colors.indigo, () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => TransactionHistoryScreen(userId: userId))
                    );
                  }),
                  _buildOutstandingCard(userId),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvailableRides(String userId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text("Available Rides", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        StreamBuilder<QuerySnapshot>(
          // REMOVE the .where('status', ...) filter so you get all rides
          stream: FirebaseFirestore.instance.collection('Rides').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            // Filter logic: Only show rides that have NOT reached capacity
            var availableRides = snapshot.data!.docs.where((doc) {
              var ride = doc.data() as Map<String, dynamic>;
              int currentPax = ride['passengerCount'] ?? 0;
              int maxPax = ride['maxPax'] ?? 0;
              return currentPax < maxPax; // Only return if there is still room
            }).toList();

            if (availableRides.isEmpty) return const Text("No rides available right now.");

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: availableRides.length,
              itemBuilder: (context, index) {
                var ride = availableRides[index];
                String plate = ride.data() is Map && (ride.data() as Map).containsKey('plateNumber')
                    ? ride['plateNumber']
                    : 'N/A';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text("${ride['pickup']} ➔ ${ride['destination']}"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Date: ${ride['date'].toDate().toString().split(' ')[0]}"),
                        Text("Plate: $plate", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RideDetailsScreen(
                              rideId: ride.id,
                              userId: userId,
                              userRole: 'Passenger',
                            ),
                          ),
                        );
                      },
                      child: const Text("View"),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _bookRide(String rideId, String userId) async {
    final batch = FirebaseFirestore.instance.batch();

    batch.update(FirebaseFirestore.instance.collection('Rides').doc(rideId), {
      'status': 'booked',
      'passengerCount': FieldValue.increment(1)
    });

    batch.set(
        FirebaseFirestore.instance.collection('Rides').doc(rideId).collection('Bookings').doc(userId),
        {'passengerId': userId, 'timestamp': FieldValue.serverTimestamp()}
    );

    await batch.commit();
  }

  // Reusable card builder
  Widget _buildActionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  // Driver outstanding balance section
  Widget _buildOutstandingCard(String userId) {
    return Card(
      color: Colors.red.shade50,
      child: ListTile(
        leading: const Icon(Icons.payments, color: Colors.red),
        title: const Text("Total Outstanding", style: TextStyle(fontWeight: FontWeight.bold)),
        trailing: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('RidePayments')
              .where('driverId', isEqualTo: userId).where('status', isEqualTo: 'pending').snapshots(),
          builder: (context, snap) {
            double total = 0.0;
            if (snap.hasData) {
              for (var doc in snap.data!.docs) total += (doc['amount'] as num).toDouble();
            }
            return Text("RM ${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red));
          },
        ),
      ),
    );
  }
}

class MyBookingsList extends StatelessWidget {
  final String userId;
  const MyBookingsList({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Bookings"), backgroundColor: Colors.teal),
      body: StreamBuilder<QuerySnapshot>(
        // This queries the user's specific collection, which needs NO special index
        stream: FirebaseFirestore.instance
            .collection('Users').doc(userId).collection('MyBookings').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No bookings yet."));

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var booking = snapshot.data!.docs[index];
              String rideId = booking['rideId']; // Pulls the ID directly

              return Card(
                child: ListTile(
                  title: const Text("View Ride Details"),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => RideDetailsScreen(
                          rideId: rideId,
                          userId: userId,
                          userRole: 'Passenger'
                      ),
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}