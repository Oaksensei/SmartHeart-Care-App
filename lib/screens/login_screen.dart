import 'package:flutter/material.dart';
import '../routes/app_routes.dart';

import '../models/user_model.dart';
import '../services/storage_service.dart';
import '../utils/mock_data.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _handleLogin() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    // Validation
    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter phone number and password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Attempt Login via StorageService
    final user = await StorageService.loginUser(phone);

    if (user != null) {
      // Success
      AppMockState.activeUser = user;
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      // Failed
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not found. Please register first.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo / Title
                const Icon(Icons.favorite, size: 80, color: Colors.blue),
                const SizedBox(height: 16),
                Text(
                  'SmartHeart Care',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Medical ECG Monitor',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),

                const SizedBox(height: 48),

                // Phone Number
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 20), // Bigger input text
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone, size: 28),
                  ),
                ),

                const SizedBox(height: 24),

                // Password
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(fontSize: 20),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock, size: 28),
                  ),
                ),

                const SizedBox(height: 40),

                // Login Button
                ElevatedButton(
                  onPressed: _handleLogin,
                  child: const Text('LOGIN'),
                ),

                const SizedBox(height: 24),

                // Create New Patient
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.register);
                  },
                  child: const Text(
                    'Create New Patient',
                    style: TextStyle(
                      fontSize: 18,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
