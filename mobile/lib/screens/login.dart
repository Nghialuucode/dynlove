import 'package:flutter/material.dart';
import '../api.dart';
import '../socket_service.dart';
import 'home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _sent = false;
  bool _loading = false;

  Future<void> _sendOtp() async {
    if (_phone.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      await Api.requestOtp(_phone.text.trim());
      setState(() => _sent = true);
      _snack('OTP đã gửi. Nhập 123456 (demo)');
    } catch (e) {
      _snack('Lỗi: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    setState(() => _loading = true);
    try {
      await Api.verifyOtp(_phone.text.trim(), _otp.text.trim());
      SocketService.connect();
      if (mounted) {
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      _snack('Sai OTP hoặc lỗi mạng');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _snack(String s) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💕', style: TextStyle(fontSize: 80)),
              const Text('DynLove',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold,
                    color: Color(0xFFE91E63))),
              const SizedBox(height: 40),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                enabled: !_sent,
                decoration: const InputDecoration(
                  labelText: 'Số điện thoại',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_sent) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Mã OTP (thử: 123456)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _loading ? null : (_sent ? _verify : _sendOtp),
                  child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(_sent ? 'Xác nhận' : 'Gửi OTP',
                        style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
