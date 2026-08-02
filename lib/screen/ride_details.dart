import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RideDetailsScreen extends StatelessWidget {
  final String rideId;
  final String userId;
  final String userRole; // 'Driver' or 'Passenger'

  const RideDetailsScreen({
    super.key,
    required this.rideId,
    required this.userId,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Ride Details"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('Rides').doc(rideId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          var ride = snapshot.data!.data() as Map<String, dynamic>;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildInfoCard(ride),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10)],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: _buildPassengerList(rideId),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBookingBar(context, rideId),
    );
  }

  Widget _buildBookingBar(BuildContext context, String rideId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('Rides').doc(rideId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        var ride = snapshot.data!.data() as Map<String, dynamic>;

        // Get counts
        int currentPax = (ride['passengerCount'] ?? 0).toInt();
        int maxPax = (ride['maxPax'] ?? 0).toInt();

        // NEW LOGIC: Show button if Passenger AND seats are available
        bool isFull = currentPax >= maxPax;
        if (userRole != 'Passenger' || isFull) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _handleBooking(context),
            child: Text(isFull ? "RIDE FULL" : "BOOK THIS RIDE",
                style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  Future<void> _handleBooking(BuildContext context) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      var rideRef = FirebaseFirestore.instance.collection('Rides').doc(rideId);

      // 1. Increment passenger count only
      batch.update(rideRef, {
        'passengerCount': FieldValue.increment(1)
      });

      // 2. Add to Ride Bookings
      batch.set(
          rideRef.collection('Bookings').doc(userId),
          {'passengerId': userId, 'timestamp': FieldValue.serverTimestamp()}
      );

      // 3. Add to User's MyBookings
      batch.set(
          FirebaseFirestore.instance.collection('Users').doc(userId).collection('MyBookings').doc(rideId),
          {'rideId': rideId, 'timestamp': FieldValue.serverTimestamp()}
      );

      await batch.commit();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ride booked successfully!")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget _buildInfoCard(Map<String, dynamic> ride) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Route", style: TextStyle(color: Colors.grey.shade600)),
                Chip(label: Text("Status: ${ride['status'].toUpperCase()}",
                    style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 8),
            Text("${ride['pickup']} ➔ ${ride['destination']}",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _infoTile(Icons.calendar_today, "Date", ride['date']?.toDate().toString().split(' ')[0] ?? 'N/A'),
                _infoTile(Icons.people, "Capacity", "${ride['maxPax']} pax"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.teal),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPassengerList(String rideId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Rides').doc(rideId).collection('Bookings').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        int count = snapshot.data!.docs.length;
        if (count == 0) return const Text("No passengers yet.");

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Total Bookings: $count", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: count,
                itemBuilder: (context, index) {
                  var booking = snapshot.data!.docs[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text("Passenger: ${booking['passengerId']}"),
                      subtitle: Text("Booked: ${booking['timestamp'] != null ? booking['timestamp'].toDate().toString().split('.')[0] : 'N/A'}"),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}