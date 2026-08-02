import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ride_details.dart';

class MyRidesListScreen extends StatelessWidget {
  final String userId;

  const MyRidesListScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Posted Rides"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Rides')
            .where('driverId', isEqualTo: userId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("You haven't posted any rides yet."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var ride = snapshot.data!.docs[index];
              var data = ride.data() as Map<String, dynamic>;

              // ... inside your ListView.builder ...
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text("${data['pickup']} ➔ ${data['destination']}"),
                  // Updated Subtitle to show count
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Status: ${data['status']} • Date: ${data['date'].toDate().toString().split(' ')[0]}"),
                      const SizedBox(height: 4),
                      Text(
                        "Passengers: ${data['passengerCount'] ?? 0} / ${data['maxPax']}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: (data['passengerCount'] ?? 0) >= data['maxPax'] ? Colors.red : Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true, // Allows the list tile to handle the extra height
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RideDetailsScreen(
                          rideId: ride.id,
                          userId: userId,
                          userRole: 'Driver',
                        ),
                      ),
                    );
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