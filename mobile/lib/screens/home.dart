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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _couple;
  Map<String, dynamic>? _pet;
  String? _inviteCode;
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  int _currentTab = 0; // 0: Nhà & Kỷ niệm, 1: Nuôi Pet, 2: Tin Nhắn

  // Pet interactive state
  String _petDialogue = "Chạm vào tớ để chơi đùa nha! Meo meo~";
  late AnimationController _petBounceController;
  late Animation<double> _petBounceAnimation;

  @override
  void initState() {
    super.initState();
    _petBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _petBounceAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _petBounceController, curve: Curves.easeInOut),
    );

    _load();

    // Listen to real-time events
    SocketService.on('pet:update', (d) {
      if (mounted) {
        setState(() {
          _pet = d['pet'];
          final action = d['action'];
          if (action == 'feed') {
            _petDialogue = "Ngon quá! Cảm ơn người ấy đã cho tớ ăn no nê nha 🍖✨";
          } else if (action == 'pet') {
            _petDialogue = "Thích quá à, được xoa đầu thích ghê luôn! 🥰💗";
          } else if (action == 'bathe') {
            _petDialogue = "Tắm mát rượi, thơm tho sạch sẽ rồi nè! 🛁🫧";
          }
        });
      }
    });

    SocketService.on('love:touch', (d) {
      if (mounted) {
        _showHeartPopup();
      }
    });
  }

  @override
  void dispose() {
    _petBounceController.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final c = await Api.myCouple();
      if (mounted) setState(() => _couple = c);
      final p = await Api.myPet();
      if (mounted) setState(() => _pet = p);
    } catch (_) {
      // Chưa ghép đôi
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createInvite() async {
    try {
      final res = await Api.createInvite();
      if (mounted) {
        setState(() => _inviteCode = res['invite_code']);
      }
    } catch (e) {
      _snack('Lỗi tạo mã: $e');
    }
  }

  Future<void> _join(String code) async {
    if (code.isEmpty) return;
    try {
      await Api.joinCouple(code);
      await _load();
      _snack('🎉 Kết nối thành công với người ấy!');
    } catch (e) {
      _snack('Lỗi kết nối: Mã không đúng hoặc đã kết nối');
    }
  }

  Future<void> _interact(String action) async {
    try {
      final res = await Api.interact(action);
      if (mounted) {
        setState(() {
          _pet = res['pet'];
          if (action == 'feed') {
            _petDialogue = "Yummy! Bạn vừa cho tớ ăn ngon tuyệt cú mèo! 🍖";
          } else if (action == 'pet') {
            _petDialogue = "Dạ meo meo~ Đang sướng rơn người vì được xoa đầu nè! 😻";
          } else if (action == 'bathe') {
            _petDialogue = "Bong bóng xà phòng bay đầy trời rồi! Mát mẻ quá! 🫧";
          }
        });
      }
    } catch (e) {
      _snack('Lỗi tương tác: $e');
    }
  }

  void _showHeartPopup() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('💖 ', style: TextStyle(fontSize: 22)),
            Text(
              'Người ấy vừa chạm tim gửi yêu thương!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(' 💖', style: TextStyle(fontSize: 22)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFFF5277),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  int _daysTogether() {
    if (_couple == null || _couple!['start_love_date'] == null) return 0;
    try {
      final start = DateTime.parse(_couple!['start_love_date']);
      return DateTime.now().difference(start).inDays;
    } catch (_) {
      return 1;
    }
  }

  void _snack(String s) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_couple == null) return _buildPairingView();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: AssetImage('assets/app_icon.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text('DynLove', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Gửi yêu thương',
            icon: const Icon(Icons.favorite_rounded, color: Color(0xFFFF5277), size: 28),
            onPressed: () {
              SocketService.loveTouch();
              _showHeartPopup();
            },
          ),
          IconButton(
            tooltip: 'Trò chuyện',
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF2D3142)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // 1. D-Day Couple Banner
              _buildDaysCounterCard(),
              const SizedBox(height: 20),

              // 2. Interactive Pet Sanctuary
              if (_pet != null) _buildPetSanctuaryCard(),

              const SizedBox(height: 20),

              // 3. Quick Action Cards & Daily Love Tips
              _buildLoveMilestoneCard(),
              const SizedBox(height: 20),

              // 4. Logout / Connection status
              _buildFooterCard(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildDaysCounterCard() {
    final days = _daysTogether();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF758C), Color(0xFFFF5277)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5277).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'Hành trình bên nhau',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                onPressed: () => _snack('Đã ghi nhớ $days ngày bên nhau!'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$days',
                style: const TextStyle(
                  fontSize: 68,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'ngày',
                style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Mỗi ngày trôi qua là một kỷ niệm đẹp cùng người ấy 💕',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }

  Widget _buildPetSanctuaryCard() {
    final level = _pet!['level'] ?? 1;
    final exp = _pet!['exp'] ?? 0;
    final hunger = _pet!['hunger'] ?? 100;
    final happiness = _pet!['happiness'] ?? 100;

    // Tiến hóa theo cấp
    String petEmoji = '🐱';
    String petTitle = 'Mèo Con Cute';
    if (level >= 16) {
      petEmoji = '🐉';
      petTitle = 'Rồng Tình Yêu Vĩ Đại';
    } else if (level >= 6) {
      petEmoji = '🦊';
      petTitle = 'Cáo Hồng Thông Thái';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pet Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    petTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF2D3142)),
                  ),
                  const SizedBox(height: 2),
                  Text('Thú cưng chung của 2 bạn', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Cấp độ $level',
                  style: const TextStyle(color: Color(0xFFFF5277), fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Dialogue Balloon
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F5FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEADBFC)),
            ),
            child: Row(
              children: [
                const Text('💬 ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    _petDialogue,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6B4E71), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Pet Character Animation
          GestureDetector(
            onTap: () => _interact('pet'),
            child: AnimatedBuilder(
              animation: _petBounceAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _petBounceAnimation.value),
                  child: Container(
                    width: 140,
                    height: 140,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFFD1DC).withOpacity(0.6),
                          const Color(0xFFFFF0F5).withOpacity(0.0),
                        ],
                      ),
                    ),
                    child: Text(
                      petEmoji,
                      style: const TextStyle(fontSize: 82),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),

          // EXP & Stats Progress
          _buildStatBar('Kinh nghiệm (EXP)', exp % 100, 100, const Color(0xFFFF85A2)),
          const SizedBox(height: 8),
          _buildStatBar('Độ no', hunger, 100, const Color(0xFFFFB703)),
          const SizedBox(height: 8),
          _buildStatBar('Hạnh phúc', happiness, 100, const Color(0xFF06D6A0)),

          const SizedBox(height: 22),

          // Interactive Action Buttons
          Row(
            children: [
              Expanded(
                child: _buildActionTile(
                  icon: '🍖',
                  title: 'Cho ăn',
                  subtitle: '+20 no',
                  color: const Color(0xFFFFF8E7),
                  onTap: () => _interact('feed'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionTile(
                  icon: '🤚',
                  title: 'Xoa đầu',
                  subtitle: '+10 vui',
                  color: const Color(0xFFFFF0F5),
                  onTap: () => _interact('pet'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionTile(
                  icon: '🛁',
                  title: 'Tắm rửa',
                  subtitle: '+15 EXP',
                  color: const Color(0xFFEBF7FF),
                  onTap: () => _interact('bathe'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBar(String label, int value, int max, Color color) {
    final double percent = (value / max).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$value%',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.03)),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoveMilestoneCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cột Mốc Kỷ Niệm Tiếp Theo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2D3142)),
          ),
          const SizedBox(height: 12),
          _milestoneItem('100 Ngày Bên Nhau', 100),
          const Divider(height: 16),
          _milestoneItem('200 Ngày Yêu Thương', 200),
          const Divider(height: 16),
          _milestoneItem('1 Năm Ngọt Ngào (365 Ngày)', 365),
        ],
      ),
    );
  }

  Widget _milestoneItem(String title, int targetDays) {
    final current = _daysTogether();
    final remaining = targetDays - current;
    final isPassed = remaining <= 0;

    return Row(
      children: [
        Icon(
          isPassed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: isPassed ? const Color(0xFF06D6A0) : const Color(0xFFFF5277),
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: isPassed ? TextDecoration.lineThrough : null,
              color: isPassed ? Colors.grey : const Color(0xFF2D3142),
            ),
          ),
        ),
        Text(
          isPassed ? 'Đã đạt' : 'Còn $remaining ngày',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isPassed ? Colors.grey : const Color(0xFFFF5277),
          ),
        ),
      ],
    );
  }

  Widget _buildFooterCard() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: () async {
            await Api.logout();
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            }
          },
          icon: const Icon(Icons.logout_rounded, color: Colors.grey, size: 18),
          label: const Text('Đăng xuất', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildPairingView() {
    return Scaffold(
      appBar: AppBar(title: const Text('Kết Nối Trái Tim 💕')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: Column(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage('assets/app_icon.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Chưa Ghép Đôi Cặp Đôi',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF2D3142)),
              ),
              const SizedBox(height: 8),
              Text(
                'Tạo mã mời gửi cho người ấy hoặc nhập mã để kết nối',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),

              // Create Invite
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Text('Bạn là người tạo phòng?', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _createInvite,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5277),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.favorite_rounded),
                      label: const Text('Lấy Mã Mời Của Bạn'),
                    ),
                    if (_inviteCode != null) ...[
                      const SizedBox(height: 16),
                      SelectableText(
                        _inviteCode!,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                          color: Color(0xFFFF5277),
                        ),
                      ),
                      const Text('Gửi mã này cho người ấy nhé!', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Join Couple
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    const Text('Hoặc nhập mã của người ấy:', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _codeCtrl,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 4),
                      decoration: InputDecoration(
                        hintText: 'NHẬP MÃ MỜI',
                        filled: true,
                        fillColor: const Color(0xFFFFF7F8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => _join(_codeCtrl.text.trim().toUpperCase()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D3142),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Kết Nối Ngay 💑'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              TextButton(
                onPressed: () async {
                  await Api.logout();
                  if (mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                },
                child: const Text('Đăng xuất tài khoản', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
