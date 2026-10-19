import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../socket_service.dart';
import 'chat.dart';
import 'login.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _couple;
  Map<String, dynamic>? _pet;
  String? _inviteCode;
  final _codeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    SocketService.on('pet:update', (d) {
      if (mounted) {
        setState(() => _pet = d['pet']);
      }
    });
  }

  Future<void> _load() async {
    try {
      final c = await Api.myCouple();
      if (mounted) setState(() => _couple = c);
      final p = await Api.myPet();
      if (mounted) setState(() => _pet = p);
    } catch (_) {
      // Chưa ghép đôi — bỏ qua
    }
  }

  Future<void> _createInvite() async {
    final res = await Api.createInvite();
    if (mounted) {
      setState(() => _inviteCode = res['invite_code']);
    }
  }

  Future<void> _join(String code) async {
    await Api.joinCouple(code);
    await _load();
  }

  Future<void> _interact(String action) async {
    final res = await Api.interact(action);
    if (mounted) {
      setState(() => _pet = res['pet']);
    }
  }

  int _daysTogether() {
    if (_couple == null) return 0;
    final start = DateTime.parse(_couple!['start_love_date']);
    return DateTime.now().difference(start).inDays;
  }

  @override
  Widget build(BuildContext context) {
    if (_couple == null) return _buildPairing();
    return _buildMain();
  }

  Widget _buildPairing() {
    return Scaffold(
      appBar: AppBar(title: const Text('Kết nối cặp đôi')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Bạn chưa kết nối với ai 💔',
                style: TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _createInvite,
              icon: const Icon(Icons.share),
              label: const Text('Tạo mã mời'),
            ),
            if (_inviteCode != null) ...[
              const SizedBox(height: 16),
              SelectableText('Mã của bạn: $_inviteCode',
                  style: const TextStyle(fontSize: 22,
                    fontWeight: FontWeight.bold, letterSpacing: 4)),
            ],
            const Divider(height: 48),
            const Text('Hoặc nhập mã của người ấy:'),
            const SizedBox(height: 12),
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                border: OutlineInputBorder(), labelText: 'Mã mời'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _join(_codeCtrl.text.trim().toUpperCase()),
              child: const Text('Kết nối'),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () async {
                await Api.logout();
                if (mounted) {
                  Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
                }
              },
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMain() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DynLove 💕'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble),
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ChatScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Colors.pink.shade50,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text('💑 Bên nhau được'),
                    const SizedBox(height: 8),
                    Text('${_daysTogether()}',
                        style: const TextStyle(fontSize: 56,
                          fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
                    const Text('ngày'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_pet != null) _buildPetCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildPetCard() {
    final level = _pet!['level'] ?? 1;
    final exp = _pet!['exp'] ?? 0;
    final emoji = level < 6 ? '🐱' : level < 16 ? '🦊' : '🐉';
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 100)),
            Text('Cấp $level — EXP: $exp',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Wrap(spacing: 10, children: [
              _actionBtn('🍖 Cho ăn', 'feed'),
              _actionBtn('🤚 Xoa đầu', 'pet'),
              _actionBtn('🛁 Tắm', 'bathe'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(String label, String action) {
    return ElevatedButton(
      onPressed: () => _interact(action),
      child: Text(label),
    );
  }
}
