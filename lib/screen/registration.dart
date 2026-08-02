import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afcm_assignment/screen/dashboard.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _icController = TextEditingController();

  String _selectedRole = 'Passenger';
  bool _isLoginView = false;

  // --- SIGN UP LOGIC (Unchanged) ---
  Future<void> _registerUser() async {
    if (_nameController.text.isEmpty || _usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Please fill in all required fields');
      return;
    }
    if (_selectedRole == 'Driver' && _icController.text.isEmpty) {
      _showSnackBar('Drivers must provide an IC number');
      return;
    }
    try {
      String username = _usernameController.text.trim();
      var userCheck = await FirebaseFirestore.instance.collection('Users').doc(username).get();
      if (userCheck.exists) {
        _showSnackBar('Username already taken.');
        return;
      }
      await FirebaseFirestore.instance.collection('Users').doc(username).set({
        'name': _nameController.text.trim(),
        'username': username,
        'password': _passwordController.text,
        'role': _selectedRole,
        'uid': username,
        'wallet_balance': 0.0,
        'ic_number': _selectedRole == 'Driver' ? _icController.text.trim() : null,
        'is_verified': false,
        'current_location': const GeoPoint(0, 0),
      });
      if (!mounted) return;
      _navigateToDashboard(username);
    } catch (e) {
      _showSnackBar('Registration Failed: $e');
    }
  }

  // --- LOGIN LOGIC (Unchanged) ---
  Future<void> _loginUser() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Please fill in all fields');
      return;
    }
    try {
      var userDoc = await FirebaseFirestore.instance.collection('Users').doc(_usernameController.text.trim()).get();
      if (userDoc.exists && userDoc['password'] == _passwordController.text) {
        _navigateToDashboard(_usernameController.text.trim());
      } else {
        _showSnackBar('Invalid username or password.');
      }
    } catch (e) {
      _showSnackBar('Login Error: $e');
    }
  }

  void _navigateToDashboard(String username) => Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (context) => DashboardScreen(userId: username)));

  void _showSnackBar(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_car, size: 64, color: Colors.teal),
                  const SizedBox(height: 16),
                  Text(_isLoginView ? 'Welcome Back' : 'Create Account',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),

                  if (!_isLoginView) _buildTextField(_nameController, 'Full Name', Icons.person),
                  _buildTextField(_usernameController, 'Username', Icons.alternate_email),
                  _buildTextField(_passwordController, 'Password', Icons.lock, obscure: true),

                  if (!_isLoginView) ...[
                    const SizedBox(height: 16),
                    _buildRoleSelection(),
                    if (_selectedRole == 'Driver')
                      _buildTextField(_icController, 'IC Number', Icons.badge, isNumeric: true),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                        onPressed: _isLoginView ? _loginUser : _registerUser,
                        child: Text(_isLoginView ? 'LOGIN' : 'REGISTER', style: const TextStyle(fontWeight: FontWeight.bold))
                    ),
                  ),
                  TextButton(
                      onPressed: () => setState(() => _isLoginView = !_isLoginView),
                      child: Text(_isLoginView ? "Don't have an account? Sign up" : "Already have an account? Login")
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper widgets for clean code
  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false, bool isNumeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Column(
      children: [
        RadioListTile(title: const Text('Passenger'), value: 'Passenger', groupValue: _selectedRole, onChanged: (v) => setState(() => _selectedRole = v!)),
        RadioListTile(title: const Text('Driver'), value: 'Driver', groupValue: _selectedRole, onChanged: (v) => setState(() => _selectedRole = v!)),
      ],
    );
  }
}