import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/session_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  String? errorMsg;

  @override
  void initState() {
    super.initState();

    emailController.text = "test@test.com";
    passwordController.text = "asdf1234\$\$";
  }

  @override
  void dispose() {
    // Remember to dispose controllers
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      isLoading = true;
      errorMsg = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc(
        'rpc_learner_login',
        params: {
          'p_email': emailController.text.trim(),
          'p_password': passwordController.text.trim(),
        },
      );

      if (!mounted) return;

      // Validate response
      if (response == null || response.isEmpty) {
        setState(() => errorMsg = 'Invalid credentials.');
        return;
      }

      final user = response[0];
      await SessionService.saveSession(Map<String, dynamic>.from(user));

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        }
      });
    } catch (e) {
      if (mounted) setState(() => errorMsg = 'Login failed: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/bg.jpg', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.5)),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: emailController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (errorMsg != null)
                    Text(errorMsg!, style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Login', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                    child: const Text('← Back to Home', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}