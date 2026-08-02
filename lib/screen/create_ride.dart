import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class CreateRideScreen extends StatefulWidget {
  final String userId;
  const CreateRideScreen({super.key, required this.userId});

  @override
  State<CreateRideScreen> createState() => _CreateRideScreenState();
}

class _CreateRideScreenState extends State<CreateRideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _destinationController = TextEditingController();
  final _paxController = TextEditingController();
  final _plateNumberController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  List<dynamic> _pickupResults = [];
  List<dynamic> _destResults = [];

  Future<void> _searchAddress(String query, bool isPickup) async {
    if (query.length < 3) return;
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=3&countrycodes=my');
      final response = await http.get(url, headers: {'User-Agent': 'carpool_app'});
      if (response.statusCode == 200) {
        setState(() => isPickup ? _pickupResults = json.decode(response.body) : _destResults = json.decode(response.body));
      }
    } catch (e) {
      debugPrint("Search error: $e");
    }
  }

  Future<void> _createRide() async {
    if (!_formKey.currentState!.validate()) return;

    await FirebaseFirestore.instance.collection('Rides').add({
      'driverId': widget.userId,
      'pickup': _pickupController.text.trim(),
      'destination': _destinationController.text.trim(),
      'maxPax': int.parse(_paxController.text),
      'plateNumber': _plateNumberController.text.trim(),
      'date': Timestamp.fromDate(_selectedDate),
      'status': 'available',
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Ride posted successfully!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Post New Ride"), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Route Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildLocationField(_pickupController, "Pickup Location", true),
              _buildResults(_pickupResults, _pickupController, true),
              const SizedBox(height: 10),
              _buildLocationField(_destinationController, "Destination", false),
              _buildResults(_destResults, _destinationController, false),

              const SizedBox(height: 25),
              const Text("Ride Specifications", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _paxController,
                      decoration: const InputDecoration(labelText: 'Max Pax', border: OutlineInputBorder(), prefixIcon: Icon(Icons.people)),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _plateNumberController,
                      decoration: const InputDecoration(labelText: 'Plate No', border: OutlineInputBorder(), prefixIcon: Icon(Icons.directions_car)),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.teal),
                  title: const Text("Ride Date"),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                  onTap: () async {
                    DateTime? picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2027));
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                ),
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: _createRide,
                  child: const Text("POST RIDE", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationField(TextEditingController controller, String label, bool isPickup) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.location_on)),
      onChanged: (v) => _searchAddress(v, isPickup),
      validator: (v) => v!.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildResults(List<dynamic> results, TextEditingController controller, bool isPickup) {
    if (results.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 150,
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: ListView.builder(
        itemCount: results.length,
        itemBuilder: (context, i) => ListTile(
          title: Text(results[i]['display_name'], style: const TextStyle(fontSize: 12), maxLines: 2),
          onTap: () {
            setState(() {
              controller.text = results[i]['display_name'];
              isPickup ? _pickupResults = [] : _destResults = [];
            });
          },
        ),
      ),
    );
  }
}