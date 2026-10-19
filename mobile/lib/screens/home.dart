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
  Map<String, dynamic>? _missions;
  String? _inviteCode;
  bool _creatorWaiting = false; // true = đã tạo mã, đang chờ người ấy
  final _codeCtrl = TextEditingController();
  DateTime? _selectedLoveDate;
  bool _loading = false;

  // Pet animation
  String _petDialogue = 'Chạm vào tớ để xoa đầu! Meo meo~';
  late AnimationController _petBounceController;
  late Animation<double> _petBounceAnimation;
  late AnimationController _heartController;
  late Animation<double> _heartAnimation;

  @override
  void initState() {
    super.initState();
    _petBounceController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _petBounceAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _petBounceController, curve: Curves.easeInOut),
    );
    _heartController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _heartAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.elasticOut),
    );

    _load();

    SocketService.on('pet:update', (d) {
      if (mounted) {
        setState(() {
          _pet = d['pet'];
          final bool cooperative = d['cooperativeBonus'] == true;
          final bool waiting = d['waitingForPartner'] == true;
          final action = d['action'];
          if (action == 'feed') {
            _petDialogue = cooperative
                ? 'Cả hai cùng cho tớ ăn! Ngon xuất sắc! 🍖🎉'
                : waiting
                    ? 'Người ấy vừa cho tớ ăn, chờ bạn cùng cho ăn nha! 🍖💕'
                    : 'Yummy! Bạn vừa cho tớ ăn, chờ người ấy cùng cho ăn nhé! 🍖';
          } else if (action == 'bathe') {
            _petDialogue = cooperative
                ? 'Cả hai tắm cho tớ! Thơm tho sạch sẽ lắm! 🛁🎉'
                : 'Mát mẻ quá! Đang chờ người ấy tắm cùng để tính điểm! 🛁';
          } else {
            _petDialogue = 'Được xoa đầu sướng rơn! Cảm ơn bạn nha! 🥰';
          }
        });
      }
    });

    SocketService.on('couple:joined', (d) {
      if (mounted) _load();
    });

    SocketService.on('checkin:both', (d) {
      if (mounted) {
        _snack('🎉 Cả hai đã điểm danh! +${d['bonusExp']} EXP');
        _load();
      }
    });

    SocketService.on('love:touch', (_) {
      if (mounted) {
        _heartController.forward(from: 0);
        _snack('💖 Người ấy vừa gửi yêu thương!');
      }
    });
  }

  @override
  void dispose() {
    _petBounceController.dispose();
    _heartController.dispose();
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
      final m = await Api.missions();
      if (mounted) setState(() => _missions = m);
    } catch (_) {
      // Chưa ghép đôi
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createInvite() async {
    setState(() => _loading = true);
    try {
      final res = await Api.createInvite();
      if (mounted) {
        setState(() {
          _inviteCode = res['invite_code'];
          _creatorWaiting = true;
        });
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception:', '').trim();
      if (msg.contains('already_paired')) {
        _snack('Bạn đã ghép đôi rồi, hãy làm mới trang!');
        await _load();
      } else {
        _snack('Lỗi: $msg');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join(String code) async {
    if (code.isEmpty) {
      _snack('Vui lòng nhập mã mời');
      return;
    }
    setState(() => _loading = true);
    try {
      final dateStr = _selectedLoveDate != null
          ? DateFormat('yyyy-MM-dd').format(_selectedLoveDate!)
          : null;
      await Api.joinCouple(code, startLoveDate: dateStr);
      await _load();
      _snack('🎉 Kết nối thành công với người ấy!');
    } catch (e) {
      final msg = e.toString().replaceAll('Exception:', '').trim();
      if (msg.contains('cannot_join_own_room')) {
        _snack('Không thể nhập mã của chính mình!');
      } else if (msg.contains('room_full')) {
        _snack('Phòng này đã đủ 2 người rồi!');
      } else if (msg.contains('code_not_found')) {
        _snack('Mã mời không đúng, kiểm tra lại nhé!');
      } else {
        _snack('Lỗi kết nối: $msg');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doCheckin() async {
    try {
      final res = await Api.checkin();
      if (mounted) {
        setState(() => _pet = res['pet'] ?? _pet);
        if (res['both_checked_in'] == true) {
          _snack('🎉 Cả hai đã điểm danh! Thú cưng nhận +${res['bonus_exp']} EXP!');
        } else {
          _snack('✅ Đã điểm danh! Đang chờ người ấy điểm danh cùng...');
        }
        await _load();
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception:', '').trim();
      if (msg.contains('already_checkin_today')) {
        _snack('Bạn đã điểm danh hôm nay rồi! 🌟');
      } else {
        _snack('Lỗi: $msg');
      }
    }
  }

  Future<void> _interact(String action) async {
    try {
      final res = await Api.interact(action);
      if (mounted) {
        setState(() {
          _pet = res['pet'];
          _petDialogue = res['message'] ?? _petDialogue;
        });
        if (res['cooperative_bonus'] == true) {
          _snack('🎉 ${res['message']}');
        }
        await _load();
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception:', '').trim();
      if (msg.contains('checkin_required')) {
        _snack('Cả 2 cần điểm danh trước khi chăm thú cưng! 📅');
      } else if (msg.contains('daily_limit_reached')) {
        _snack(msg);
      } else {
        _snack('Lỗi: $msg');
      }
    }
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s, style: const TextStyle(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  int _daysTogether() {
    if (_couple == null || _couple!['start_love_date'] == null) return 0;
    try {
      final start = DateTime.parse(_couple!['start_love_date']);
      return DateTime.now().difference(start).inDays;
    } catch (_) {
      return 0;
    }
  }

  // ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading && _couple == null && _inviteCode == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF5F7),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF5277))),
      );
    }
    if (_couple == null) return _buildPairingView();
    return _buildMainView();
  }

  // ═══════════════════════════════ MAIN VIEW ════════════════════════════════

  Widget _buildMainView() {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _load,
        color: const Color(0xFFFF5277),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            children: [
              _buildDaysBanner(),
              const SizedBox(height: 16),
              _buildCheckinCard(),
              const SizedBox(height: 16),
              if (_pet != null) _buildPetCard(),
              const SizedBox(height: 16),
              if (_missions != null) _buildMissionsCard(),
              const SizedBox(height: 16),
              _buildMilestonesCard(),
              const SizedBox(height: 16),
              _buildFooter(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30, height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: AssetImage('assets/app_icon.png'), fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Text('DynLove', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Color(0xFF2D3142))),
        ],
      ),
      actions: [
        AnimatedBuilder(
          animation: _heartAnimation,
          builder: (_, __) => Transform.scale(
            scale: _heartAnimation.value,
            child: IconButton(
              tooltip: 'Gửi yêu thương',
              icon: const Icon(Icons.favorite_rounded, color: Color(0xFFFF5277), size: 28),
              onPressed: () {
                SocketService.loveTouch();
                _heartController.forward(from: 0);
                _snack('💖 Đã gửi yêu thương!');
              },
            ),
          ),
        ),
        IconButton(
          tooltip: 'Tin nhắn',
          icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF2D3142)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Days Banner ──
  Widget _buildDaysBanner() {
    final days = _daysTogether();
    final members = _couple?['members'] as List?;
    final names = members?.map((m) => (m['full_name'] as String? ?? '').split(' ').last).toList() ?? [];
    final coupleLabel = names.length >= 2 ? '${names[0]} & ${names[1]}' : 'Cặp Đôi';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFFF758C), Color(0xFFFF4C75)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: const Color(0xFFFF5277).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                  const SizedBox(width: 5),
                  Text(coupleLabel, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
              Text(
                _couple?['start_love_date'] != null
                    ? DateFormat('dd/MM/yyyy').format(DateTime.parse(_couple!['start_love_date']))
                    : '',
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$days', style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -2, height: 1)),
              const SizedBox(width: 8),
              const Text('ngày\nbên nhau', style: TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w700, height: 1.3)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            days == 0 ? 'Hành trình yêu thương bắt đầu hôm nay! 💕' : 'Mỗi ngày trôi qua là một kỷ niệm đẹp cùng người ấy 💕',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }

  // ── Check-in Card ──
  Widget _buildCheckinCard() {
    final myCheckin = _pet?['my_checkin_today'] == true;
    final bothCheckin = _pet?['both_checkin_today'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFFFF0F5), borderRadius: BorderRadius.circular(12)),
                child: const Text('📅', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Điểm Danh Hằng Ngày', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF2D3142))),
                    Text(
                      bothCheckin ? '✅ Cả hai đã điểm danh hôm nay!' : myCheckin ? '⏳ Đang chờ người ấy điểm danh...' : 'Điểm danh để nhận phần thưởng cùng người ấy!',
                      style: TextStyle(fontSize: 12, color: bothCheckin ? const Color(0xFF06D6A0) : Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _checkinDot('Bạn', myCheckin),
              const SizedBox(width: 12),
              _checkinDot('Người ấy', bothCheckin),
              const Spacer(),
              if (!myCheckin)
                FilledButton.icon(
                  onPressed: _doCheckin,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5277),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.favorite_rounded, size: 16),
                  label: const Text('Điểm danh', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFF0FFF8), borderRadius: BorderRadius.circular(14)),
                  child: const Text('Đã điểm danh ✅', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF06D6A0))),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _checkinDot(String label, bool done) {
    return Column(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: done ? const Color(0xFF06D6A0) : Colors.grey.shade100,
            shape: BoxShape.circle,
            border: Border.all(color: done ? const Color(0xFF06D6A0) : Colors.grey.shade300, width: 2),
          ),
          child: Center(child: Icon(done ? Icons.check_rounded : Icons.person_rounded, color: done ? Colors.white : Colors.grey.shade400, size: 18)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
      ],
    );
  }

  // ── Pet Card ──
  Widget _buildPetCard() {
    final level = _pet!['level'] ?? 1;
    final exp = (_pet!['exp'] ?? 0) as int;
    final hunger = (_pet!['hunger'] ?? 100) as int;
    final happiness = (_pet!['happiness'] ?? 100) as int;
    final myFeed = (_pet!['my_feed_today'] ?? 0) as int;
    final myBathe = (_pet!['my_bathe_today'] ?? 0) as int;
    final partnerFed = _pet!['partner_fed_today'] == true;
    final partnerBathed = _pet!['partner_bathed_today'] == true;
    final bothCheckin = _pet!['both_checkin_today'] == true;

    String petEmoji = '🐱';
    String petTitle = 'Mèo Con Dễ Thương';
    String petBg = '💗';
    if (level >= 16) { petEmoji = '🐉'; petTitle = 'Rồng Tình Yêu'; petBg = '✨'; }
    else if (level >= 11) { petEmoji = '🦁'; petTitle = 'Sư Tử Dũng Cảm'; petBg = '🌟'; }
    else if (level >= 6) { petEmoji = '🦊'; petTitle = 'Cáo Hồng Thông Thái'; petBg = '🌸'; }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(petTitle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF2D3142))),
                Text('$petBg Thú cưng chung của hai bạn', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFFFF0F5), borderRadius: BorderRadius.circular(14)),
                child: Text('Cấp $level', style: const TextStyle(color: Color(0xFFFF5277), fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Dialogue
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFFF9F5FF), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFEADBFC))),
            child: Row(children: [
              const Text('💬 ', style: TextStyle(fontSize: 15)),
              Expanded(child: Text(_petDialogue, style: const TextStyle(fontSize: 12, color: Color(0xFF6B4E71), fontWeight: FontWeight.w600))),
            ]),
          ),

          const SizedBox(height: 18),

          // Pet Animation
          GestureDetector(
            onTap: () => _interact('pet'),
            child: AnimatedBuilder(
              animation: _petBounceAnimation,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _petBounceAnimation.value),
                child: Container(
                  width: 130, height: 130,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [const Color(0xFFFFD1DC).withOpacity(0.6), const Color(0xFFFFF0F5).withOpacity(0.0)]),
                  ),
                  child: Text(petEmoji, style: const TextStyle(fontSize: 80)),
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),
          Text('Chạm để xoa đầu! 🥰', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),

          const SizedBox(height: 16),

          // Stats
          _statBar('EXP', exp % 100, 100, const Color(0xFFFF85A2)),
          const SizedBox(height: 8),
          _statBar('Độ no', hunger, 100, const Color(0xFFFFB703)),
          const SizedBox(height: 8),
          _statBar('Hạnh phúc', happiness, 100, const Color(0xFF06D6A0)),

          const SizedBox(height: 20),

          // Cảnh báo điểm danh
          if (!bothCheckin)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFFE082))),
              child: const Row(children: [
                Text('⚠️ ', style: TextStyle(fontSize: 16)),
                Expanded(child: Text('Cả hai cần điểm danh trước khi chăm thú cưng!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB8860B)))),
              ]),
            ),

          // Action Buttons
          Row(
            children: [
              Expanded(child: _actionBtn(
                icon: '🍖', title: 'Cho ăn',
                subtitle: '$myFeed/2 lần',
                badge: partnerFed ? '👥' : null,
                color: const Color(0xFFFFF8E7),
                disabled: myFeed >= 2 || !bothCheckin,
                onTap: () => _interact('feed'),
              )),
              const SizedBox(width: 10),
              Expanded(child: _actionBtn(
                icon: '🤚', title: 'Xoa đầu',
                subtitle: 'Tùy ý',
                color: const Color(0xFFFFF0F5),
                onTap: () => _interact('pet'),
              )),
              const SizedBox(width: 10),
              Expanded(child: _actionBtn(
                icon: '🛁', title: 'Tắm rửa',
                subtitle: '$myBathe/2 lần',
                badge: partnerBathed ? '👥' : null,
                color: const Color(0xFFEBF7FF),
                disabled: myBathe >= 2 || !bothCheckin,
                onTap: () => _interact('bathe'),
              )),
            ],
          ),

          // Trạng thái hợp tác
          if ((_pet!['partner_fed_today'] == true || _pet!['partner_bathed_today'] == true))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: const Color(0xFFF0FFF8), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Text('💕 ', style: TextStyle(fontSize: 14)),
                  Expanded(child: Text(
                    [
                      if (partnerFed) 'Người ấy đã cho ăn, đến lượt bạn!',
                      if (partnerBathed) 'Người ấy đã tắm, đến lượt bạn!',
                    ].join(' | '),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF06D6A0)),
                  )),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statBar(String label, int value, int max, Color color) {
    final double pct = (value / max).clamp(0.0, 1.0);
    return Row(children: [
      SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600))),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: Colors.grey.shade100, valueColor: AlwaysStoppedAnimation<Color>(color)),
        ),
      ),
      const SizedBox(width: 8),
      Text('$value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
    ]);
  }

  Widget _actionBtn({
    required String icon, required String title, required String subtitle,
    required Color color, required VoidCallback onTap,
    bool disabled = false, String? badge,
  }) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Opacity(
        opacity: disabled ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.black.withOpacity(0.04))),
          child: Stack(alignment: Alignment.topRight, children: [
            Column(children: [
              Text(icon, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ]),
            if (badge != null) Positioned(top: 0, right: 6, child: Text(badge, style: const TextStyle(fontSize: 14))),
          ]),
        ),
      ),
    );
  }

  // ── Missions Card ──
  Widget _buildMissionsCard() {
    if (_missions == null) return const SizedBox.shrink();
    final daily = _missions!['daily'] as List? ?? [];
    final weekly = _missions!['weekly'] as List? ?? [];
    final monthly = _missions!['monthly'] as List? ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Text('📋', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Nhiệm Vụ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2D3142))),
          ]),
          const SizedBox(height: 14),

          if (daily.isNotEmpty) ...[
            _missionSectionHeader('Hằng Ngày', const Color(0xFFFF5277)),
            ...daily.map((m) => _missionItem(m)),
            const SizedBox(height: 12),
          ],
          if (weekly.isNotEmpty) ...[
            _missionSectionHeader('Hằng Tuần', const Color(0xFF7C4DFF)),
            ...weekly.map((m) => _missionItem(m)),
            const SizedBox(height: 12),
          ],
          if (monthly.isNotEmpty) ...[
            _missionSectionHeader('Hằng Tháng', const Color(0xFFFF8C00)),
            ...monthly.map((m) => _missionItem(m)),
          ],
        ],
      ),
    );
  }

  Widget _missionSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  Widget _missionItem(Map<String, dynamic> m) {
    final bool done = m['done'] == true;
    final int progress = (m['progress'] ?? 0) as int;
    final int target = (m['target'] ?? 1) as int;
    final double pct = (progress / target).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: done ? const Color(0xFF06D6A0) : Colors.grey.shade400, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m['title'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, decoration: done ? TextDecoration.lineThrough : null, color: done ? Colors.grey : const Color(0xFF2D3142))),
              if (!done) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: pct, minHeight: 5, backgroundColor: Colors.grey.shade100, valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF5277))),
                ),
                const SizedBox(height: 2),
                Text('$progress/$target • ${m['reward']}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ] else
                Text('Hoàn thành! ${m['reward']} 🎉', style: const TextStyle(fontSize: 11, color: Color(0xFF06D6A0), fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Milestones Card ──
  Widget _buildMilestonesCard() {
    final days = _daysTogether();
    final milestones = [
      ('100 Ngày Bên Nhau 🎊', 100),
      ('200 Ngày Yêu Thương 💕', 200),
      ('365 Ngày - 1 Năm Ngọt Ngào 🎂', 365),
      ('500 Ngày Hạnh Phúc ✨', 500),
      ('1000 Ngày Vàng 👑', 1000),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Text('🏆', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Cột Mốc Kỷ Niệm', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2D3142))),
          ]),
          const SizedBox(height: 14),
          ...milestones.map((m) {
            final isPassed = days >= m.$2;
            final remaining = m.$2 - days;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Icon(isPassed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isPassed ? const Color(0xFF06D6A0) : const Color(0xFFFF5277), size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(m.$1, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    decoration: isPassed ? TextDecoration.lineThrough : null,
                    color: isPassed ? Colors.grey : const Color(0xFF2D3142)))),
                Text(isPassed ? 'Đã đạt 🎉' : 'Còn $remaining ngày',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: isPassed ? Colors.grey : const Color(0xFFFF5277))),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return TextButton.icon(
      onPressed: () async {
        await Api.logout();
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      },
      icon: const Icon(Icons.logout_rounded, color: Colors.grey, size: 16),
      label: const Text('Đăng xuất', style: TextStyle(color: Colors.grey, fontSize: 13)),
    );
  }

  // ═══════════════════════════════ PAIRING VIEW ════════════════════════════

  Widget _buildPairingView() {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 110, height: 110,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(image: AssetImage('assets/app_icon.png'), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('DynLove 💕', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFFF5277))),
                const SizedBox(height: 6),
                Text('Kết nối hai trái tim yêu thương', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                const SizedBox(height: 32),

                // ─ Tạo phòng ─
                if (!_creatorWaiting)
                  _pairingCard(
                    child: Column(children: [
                      const Text('Bạn là người tạo phòng?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF2D3142))),
                      const SizedBox(height: 6),
                      Text('Lấy mã mời gửi cho người ấy', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _createInvite,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5277),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.favorite_rounded),
                          label: const Text('Lấy Mã Mời Của Bạn', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ),
                    ]),
                  )
                else ...[
                  // ─ Đang chờ sau khi tạo mã ─
                  _pairingCard(
                    child: Column(children: [
                      const Text('🎉 Mã mời của bạn', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF2D3142))),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(color: const Color(0xFFFFF0F5), borderRadius: BorderRadius.circular(20)),
                        child: SelectableText(
                          _inviteCode!,
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 8, color: Color(0xFFFF5277)),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('📨 Gửi mã này cho người ấy nhé!', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: const Color(0xFFF0FFF8), borderRadius: BorderRadius.circular(12)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF06D6A0))),
                          SizedBox(width: 8),
                          Text('Đang chờ người ấy nhập mã...', style: TextStyle(fontSize: 12, color: Color(0xFF06D6A0), fontWeight: FontWeight.w600)),
                        ]),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => setState(() { _inviteCode = null; _creatorWaiting = false; }),
                        child: const Text('Tạo mã mới', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                    ]),
                  ),
                ],

                const SizedBox(height: 16),

                // ─ Nhập mã ─
                if (!_creatorWaiting)
                  _pairingCard(
                    child: Column(children: [
                      const Text('Nhận được mã từ người ấy?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF2D3142))),
                      const SizedBox(height: 6),
                      Text('Nhập mã và chọn ngày yêu bắt đầu', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeCtrl,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 5, color: Color(0xFF2D3142)),
                        decoration: InputDecoration(
                          hintText: 'NHẬP MÃ MỜI',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.w400, fontSize: 16, letterSpacing: 2),
                          filled: true, fillColor: const Color(0xFFFFF7F8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Chọn ngày yêu
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedLoveDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                            helpText: 'Chọn ngày yêu bắt đầu',
                            confirmText: 'Xác nhận',
                            cancelText: 'Hủy',
                            builder: (context, child) => Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: const ColorScheme.light(primary: Color(0xFFFF5277), onPrimary: Colors.white),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) setState(() => _selectedLoveDate = picked);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedLoveDate != null ? const Color(0xFFFFF0F5) : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _selectedLoveDate != null ? const Color(0xFFFFB3C1) : Colors.grey.shade200),
                          ),
                          child: Row(children: [
                            Icon(Icons.calendar_heart_outlined, color: _selectedLoveDate != null ? const Color(0xFFFF5277) : Colors.grey.shade400, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              _selectedLoveDate != null
                                  ? '💕 Ngày yêu: ${DateFormat('dd/MM/yyyy').format(_selectedLoveDate!)}'
                                  : 'Chọn ngày bắt đầu yêu (tùy chọn)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                  color: _selectedLoveDate != null ? const Color(0xFFFF5277) : Colors.grey.shade500),
                            ),
                          ]),
                        ),
                      ),

                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : () => _join(_codeCtrl.text.trim().toUpperCase()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D3142), foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Kết Nối Ngay 💑', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ),
                    ]),
                  ),

                const SizedBox(height: 20),
                TextButton(
                  onPressed: () async {
                    await Api.logout();
                    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                  },
                  child: const Text('Đăng xuất tài khoản', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pairingCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }
}
