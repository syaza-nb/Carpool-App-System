import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BookingScreen extends StatefulWidget {
  final String userId;

  const BookingScreen({
    super.key,
    required this.userId,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  // ================= LOCATION =================
  double _latitude = 3.1390;
  double _longitude = 101.6869;

  bool _isLoadingLocation = true;

  // ================= CONTROLLERS =================
  final TextEditingController _pickupController =
  TextEditingController(text: "Fetching live GPS location...");

  final TextEditingController _destinationController =
  TextEditingController();

  // EXTRA COST CONTROLLERS
  final TextEditingController _fuelController =
  TextEditingController();

  final TextEditingController _tollController =
  TextEditingController();

  final TextEditingController _rentController =
  TextEditingController();

  final TextEditingController _otherController =
  TextEditingController();

  // ================= DATE =================
  DateTime _selectedDate = DateTime.now();

  // ================= FARE =================
  final double baseFare = 3.00;
  final double ratePerKm = 1.20;

  double totalVehicleCost = 0.00;
  double dynamicFare = 0.00;
  double _distanceInKm = 0.00;

  int _selectedPax = 1;

  // ================= SEARCH =================
  List<dynamic> _pickupSearchResults = [];
  List<dynamic> _destSearchResults = [];

  bool _isSearchingPickup = false;
  bool _isSearchingDest = false;

  GeoPoint? _selectedPickupCoordinates;
  GeoPoint? _selectedDestinationCoordinates;

  @override
  void initState() {
    super.initState();
    _getUserLiveLocation();
  }

  Widget _buildSearchResults(List<dynamic> results, bool isPickup) {
    if (results.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 150, // CRITICAL: This fixed height forces the list to show
      margin: const EdgeInsets.only(top: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.teal),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: results.length,
        itemBuilder: (context, index) {
          final place = results[index];
          return ListTile(
            title: Text(place['display_name'], style: const TextStyle(fontSize: 12)),
            onTap: () {
              setState(() {
                if (isPickup) {
                  _pickupController.text = place['display_name'];
                  _selectedPickupCoordinates = GeoPoint(double.parse(place['lat']), double.parse(place['lon']));
                  _pickupSearchResults = [];
                } else {
                  _destinationController.text = place['display_name'];
                  _selectedDestinationCoordinates = GeoPoint(double.parse(place['lat']), double.parse(place['lon']));
                  _destSearchResults = [];
                }
              });
              _calculateDynamicFare();
            },
          );
        },
      ),
    );
  }

  // ================= DATE PICKER =================
  Future<void> _selectPickupDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 30),
      ),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // ================= SEARCH LOCATION =================
  Future<void> _searchAddress(
      String query,
      bool isPickup,
      ) async {
    if (query.trim().isEmpty) {
      setState(() {
        if (isPickup) {
          _pickupSearchResults = [];
        } else {
          _destSearchResults = [];
        }
      });
      return;
    }

    setState(() {
      if (isPickup) {
        _isSearchingPickup = true;
      } else {
        _isSearchingDest = true;
      }
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=5&countrycodes=my',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'com.example.carpool_app',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data =
        json.decode(response.body);

        setState(() {
          if (isPickup) {
            _pickupSearchResults = data;
          } else {
            _destSearchResults = data;
          }
        });
      }
    } catch (e) {
      debugPrint("Search Error: $e");
    } finally {
      setState(() {
        if (isPickup) {
          _isSearchingPickup = false;
        } else {
          _isSearchingDest = false;
        }
      });
    }
  }

  // ================= CALCULATE FARE =================
  void _calculateDynamicFare() {
    if (_selectedPickupCoordinates == null ||
        _selectedDestinationCoordinates == null) {
      return;
    }

    const double earthRadius = 6371.0;

    double pLat =
        _selectedPickupCoordinates!.latitude;

    double pLon =
        _selectedPickupCoordinates!.longitude;

    double dLat =
        _selectedDestinationCoordinates!.latitude;

    double dLon =
        _selectedDestinationCoordinates!.longitude;

    double deltaLat =
        (dLat - pLat) * math.pi / 180.0;

    double deltaLon =
        (dLon - pLon) * math.pi / 180.0;

    double lat1Rad = pLat * math.pi / 180.0;
    double lat2Rad = dLat * math.pi / 180.0;

    double a =
        math.sin(deltaLat / 2) *
            math.sin(deltaLat / 2) +
            math.sin(deltaLon / 2) *
                math.sin(deltaLon / 2) *
                math.cos(lat1Rad) *
                math.cos(lat2Rad);

    double c = 2 *
        math.atan2(
          math.sqrt(a),
          math.sqrt(1 - a),
        );

    double calculatedDistance =
        earthRadius * c;

    // DISTANCE COST
    // EXTRA COSTS ONLY
    double fuel =
        double.tryParse(_fuelController.text) ??
            0.0;

    double toll =
        double.tryParse(_tollController.text) ??
            0.0;

    double rent =
        double.tryParse(_rentController.text) ??
            0.0;

    double other =
        double.tryParse(_otherController.text) ??
            0.0;

// TOTAL WITHOUT DISTANCE COST
    double grandTotal =
        fuel +
            toll +
            rent +
            other;

    setState(() {
      _distanceInKm = calculatedDistance;
      totalVehicleCost = grandTotal;
      dynamicFare =
          totalVehicleCost / _selectedPax;
    });
  }

  // ================= GET GPS =================
  Future<void> _getUserLiveLocation() async {
    try {
      bool serviceEnabled =
      await Geolocator
          .isLocationServiceEnabled();

      if (!serviceEnabled) {
        _useFallbackLocation();
        return;
      }

      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
        await Geolocator
            .requestPermission();

        if (permission ==
            LocationPermission.denied) {
          _useFallbackLocation();
          return;
        }
      }

      Position position =
      await Geolocator.getCurrentPosition(
        desiredAccuracy:
        LocationAccuracy.low,
        timeLimit:
        const Duration(seconds: 3),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;

        _selectedPickupCoordinates =
            GeoPoint(
              _latitude,
              _longitude,
            );

        _pickupController.text =
        "My Current Location (${_latitude.toStringAsFixed(4)}, ${_longitude.toStringAsFixed(4)})";

        _isLoadingLocation = false;
      });
    } catch (e) {
      _useFallbackLocation();
    }
  }

  void _useFallbackLocation() {
    setState(() {
      _latitude = 3.1390;
      _longitude = 101.6869;

      _selectedPickupCoordinates =
          GeoPoint(
            _latitude,
            _longitude,
          );

      _pickupController.text =
      "Selangor, Malaysia";

      _isLoadingLocation = false;
    });
  }

  // ================= GENERATE QR =================
  Future<void> _generateQRPayment() async {

    if (_pickupController.text.isEmpty ||
        _destinationController.text.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete all locations.',
          ),
        ),
      );

      return;
    }

    final DocumentReference splitRef =
    FirebaseFirestore.instance
        .collection('SplitPayments')
        .doc();

    // MAP FOR FIRESTORE
    Map<String, dynamic> paymentData = {
      'split_id': splitRef.id,
      'driver_id': widget.userId,
      'pickup_location':
      _pickupController.text.trim(),
      'destination':
      _destinationController.text.trim(),
      'distance_km': _distanceInKm,

      'fuel_cost':
      double.tryParse(
        _fuelController.text,
      ) ??
          0.0,

      'toll_cost':
      double.tryParse(
        _tollController.text,
      ) ??
          0.0,

      'rent_cost':
      double.tryParse(
        _rentController.text,
      ) ??
          0.0,

      'other_cost':
      double.tryParse(
        _otherController.text,
      ) ??
          0.0,

      'total_cost': totalVehicleCost,
      'amount_per_pax': dynamicFare,
      'pax': _selectedPax,

      'date': DateFormat(
        'yyyy-MM-dd',
      ).format(_selectedDate),

      'created_at':
      DateTime.now().toIso8601String(),
    };

    // SAVE TO FIRESTORE
    await splitRef.set(paymentData);

    // CONVERT TO STRING FOR QR
    String qrData = jsonEncode(paymentData);

    if (!mounted) return;

    showDialog(
      context: context,
      // Inside your _generateQRPayment method, look for the AlertDialog content:
      builder: (context) {
        return AlertDialog(
          title: const Text("Ride Payment QR", style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView( // Add this to prevent overflow inside the dialog
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // FIX: Wrap QrImageView in a SizedBox to ensure it has a layout size
                SizedBox(
                  width: 220,
                  height: 220,
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    // Removed size from here as SizedBox handles it
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "RM ${dynamicFare.toStringAsFixed(2)} / pax",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                ),
                const SizedBox(height: 10),
                Text(_destinationController.text, textAlign: TextAlign.center),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // ================= MONEY FIELD =================
  Widget _moneyField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType:
      TextInputType.number,
      onChanged: (value) =>
          _calculateDynamicFare(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border:
        const OutlineInputBorder(),
      ),
    );
  }

  // ================= SUMMARY ROW =================
  Widget _summaryRow(
      String title,
      String value,
      ) {
    return Row(
      mainAxisAlignment:
      MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
      ],
    );
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
        const Text('Calculate Fare Ride'),
        backgroundColor:
        Colors.teal,
        foregroundColor:
        Colors.white,
      ),

    body: _isLoadingLocation
    ? const Center(
    child: CircularProgressIndicator(),
    )
        : SafeArea(
    child: SingleChildScrollView(
    // Adding 'bottom' padding prevents the overflow
    // when the keyboard appears or on small screens
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 50),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
            // ================= PICKUP =================
      TextField(
        controller: _pickupController,
        decoration: InputDecoration(
          labelText: 'Pickup Location',
          prefixIcon: const Icon(Icons.my_location),
          suffixIcon: _isSearchingPickup ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) => _searchAddress(value, true),
      ),
      _buildSearchResults(_pickupSearchResults, true), // <--- Use the helper

      const SizedBox(height: 20),

// ================= DESTINATION =================
      TextField(
        controller: _destinationController,
        decoration: InputDecoration(
          labelText: 'Destination',
          prefixIcon: const Icon(Icons.location_on),
          suffixIcon: _isSearchingDest ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
          border: const OutlineInputBorder(),
        ),
        onChanged: (value) => _searchAddress(value, false),
      ),
      _buildSearchResults(_destSearchResults, false),

            // ================= DATE =================
            InkWell(
              onTap: () =>
                  _selectPickupDate(
                    context,
                  ),
              child: Container(
                padding:
                const EdgeInsets.all(
                  14,
                ),
                decoration:
                BoxDecoration(
                  border:
                  Border.all(
                    color:
                    Colors.grey,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,
                  children: [
                    Text(
                      DateFormat(
                        'EEEE, d MMM yyyy',
                      ).format(
                        _selectedDate,
                      ),
                    ),
                    const Icon(
                      Icons
                          .calendar_month,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // ================= PASSENGER =================
            Row(
              mainAxisAlignment:
              MainAxisAlignment
                  .spaceBetween,
              children: [
                const Text(
                  "Passengers",
                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed:
                      _selectedPax > 1
                          ? () {
                        setState(
                              () {
                            _selectedPax--;
                            _calculateDynamicFare();
                          },
                        );
                      }
                          : null,
                      icon: const Icon(
                        Icons
                            .remove_circle,
                      ),
                    ),
                    Text(
                      "$_selectedPax",
                      style:
                      const TextStyle(
                        fontSize: 18,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed:
                      _selectedPax < 10
                          ? () {
                        setState(
                              () {
                            _selectedPax++;
                            _calculateDynamicFare();
                          },
                        );
                      }
                          : null,
                      icon: const Icon(
                        Icons
                            .add_circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(
              height: 20,
            ),

            // ================= EXTRA COST =================
            const Text(
              "Additional Costs",
              style: TextStyle(
                fontSize: 17,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 15,
            ),

            _moneyField(
              controller:
              _fuelController,
              label:
              "Fuel Cost (RM)",
              icon: Icons
                  .local_gas_station,
            ),

            const SizedBox(
              height: 12,
            ),

            _moneyField(
              controller:
              _tollController,
              label:
              "Toll Fee (RM)",
              icon: Icons.toll,
            ),

            const SizedBox(
              height: 12,
            ),

            _moneyField(
              controller:
              _rentController,
              label:
              "Car Rental Fee (RM)",
              icon:
              Icons.car_rental,
            ),

            const SizedBox(
              height: 12,
            ),

            _moneyField(
              controller:
              _otherController,
              label:
              "Other Expenses (RM)",
              icon: Icons
                  .receipt_long,
            ),

            const SizedBox(
              height: 20,
            ),

            // ================= CALCULATE =================
            SizedBox(
              width:
              double.infinity,
              height: 50,
              child:
              ElevatedButton(
                onPressed:
                _calculateDynamicFare,
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  Colors.orange,
                  foregroundColor:
                  Colors.white,
                ),
                child: const Text(
                  "CALCULATE SPLIT",
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // ================= SUMMARY =================
            Card(
              child: Padding(
                padding:
                const EdgeInsets.all(
                  16,
                ),
                child: Column(
                  children: [
                    _summaryRow(
                      "Distance",
                      "${_distanceInKm.toStringAsFixed(2)} KM",
                    ),

                    const Divider(),

                    _summaryRow(
                      "Total Trip Cost",
                      "RM ${totalVehicleCost.toStringAsFixed(2)}",
                    ),

                    const Divider(),

                    _summaryRow(
                      "Per Passenger",
                      "RM ${dynamicFare.toStringAsFixed(2)}",
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            // ================= QR BUTTON =================
            SizedBox(
              width:
              double.infinity,
              height: 55,
              child:
              ElevatedButton.icon(
                onPressed:
                _generateQRPayment,
                style:
                ElevatedButton.styleFrom(
                  backgroundColor:
                  Colors.teal,
                  foregroundColor:
                  Colors.white,
                ),
                icon: const Icon(
                  Icons.qr_code,
                ),
                label: const Text(
                  "SAVE & GENERATE QR",
                  style: TextStyle(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
    );
  }
}