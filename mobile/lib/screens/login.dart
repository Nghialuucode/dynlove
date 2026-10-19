import 'package:flutter/material.dart';
import '../api.dart';
import '../socket_service.dart';
import 'home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _name = TextEditingController();
  bool _sent = false;
  bool _loading = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _phone.dispose();
    _otp.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phone.text.trim();
    if (phone.isEmpty) {
      _snack('Vui lòng nhập số điện thoại');
      return;
    }
    setState(() => _loading = true);
    try {
      await Api.requestOtp(phone);
      setState(() => _sent = true);
      _snack('Mã OTP demo là 123456');
    } catch (e) {
      _snack('Lỗi kết nối: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    final otp = _otp.text.trim();
    if (otp.isEmpty) {
      _snack('Vui lòng nhập mã OTP');
      return;
    }
    setState(() => _loading = true);
    try {
      await Api.verifyOtp(_phone.text.trim(), otp);
      SocketService.connect();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
          ),
        );
      }
    } catch (e) {
      _snack('Lỗi xác nhận: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String s) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s, style: const TextStyle(fontWeight: FontWeight.w500)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: const Color(0xFF2D3142),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF0F5), Color(0xFFFFEEF0), Color(0xFFF9F5FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App Icon / Logo Animation
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF5277).withOpacity(0.25),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/app_icon.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.white,
                            alignment: Alignment.center,
                            child: const Text('💕', style: TextStyle(fontSize: 48)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'DynLove',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D3142),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Không gian ngọt ngào cho hai bạn',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Login Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _sent ? 'Xác thực OTP' : 'Đăng nhập',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2D3142),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _sent
                              ? 'Nhập mã 123456 gửi tới ${_phone.text}'
                              : 'Nhập số điện thoại để kết nối với người ấy',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 20),

                        // Phone Input
                        TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          enabled: !_sent,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            labelText: 'Số điện thoại',
                            prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFFFF5277)),
                            filled: true,
                            fillColor: _sent ? Colors.grey.shade100 : const Color(0xFFFFF7F8),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        if (_sent) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: _otp,
                            keyboardType: TextInputType.number,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 6,
                              color: Color(0xFFFF5277),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Mã OTP (123456)',
                              hintText: '123456',
                              filled: true,
                              fillColor: const Color(0xFFFFF7F8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => setState(() => _sent = false),
                              child: const Text('Đổi số khác', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _loading ? null : (_sent ? _verify : _sendOtp),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5277),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              shadowColor: const Color(0xFFFF5277).withOpacity(0.4),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Text(
                                    _sent ? 'Vào Ngôi Nhà Tình Yêu 💕' : 'Tiếp Tục →',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  Text(
                    'DynLove • Kết nối trái tim mỗi ngày',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
