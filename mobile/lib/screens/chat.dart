import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../socket_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<Map<String, dynamic>> _msgs = [];
  String? _partnerTyping;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    SocketService.on('chat:new', _onNew);
    SocketService.on('chat:typing', _onTyping);
    SocketService.on('love:touch', _onLove);
  }

  @override
  void dispose() {
    SocketService.off('chat:new', _onNew);
    SocketService.off('chat:typing', _onTyping);
    SocketService.off('love:touch', _onLove);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final list = await Api.messages();
      if (mounted) {
        setState(() {
          _msgs.clear();
          _msgs.addAll(list.cast<Map<String, dynamic>>());
        });
        _scrollDown();
      }
    } catch (_) {}
  }

  void _onNew(dynamic d) {
    if (mounted) {
      setState(() => _msgs.add(Map<String, dynamic>.from(d)));
      _scrollDown();
    }
  }

  void _onTyping(dynamic d) {
    if (mounted) {
      setState(() => _partnerTyping = d['typing'] == true ? 'Người ấy đang soạn tin nhắn...' : null);
      if (d['typing'] == true) {
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) setState(() => _partnerTyping = null);
        });
      }
    }
  }

  void _onLove(dynamic _) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('💖 ', style: TextStyle(fontSize: 20)),
              Text('Người ấy vừa chạm tim gửi yêu thương!', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(' 💖', style: TextStyle(fontSize: 20)),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFFF5277),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    SocketService.sendMessage(text);
    _msgCtrl.clear();
    SocketService.typing(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F7),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: AssetImage('assets/app_icon.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Phòng Chat Đôi Ta 💕',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if (_partnerTyping != null)
                  Text(
                    _partnerTyping!,
                    style: const TextStyle(fontSize: 11, color: Color(0xFFFF5277), fontWeight: FontWeight.w600),
                  )
                else
                  const Text(
                    'Đang kết nối thời gian thực',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Gửi ngàn trái tim',
            icon: const Icon(Icons.favorite_rounded, color: Color(0xFFFF5277), size: 26),
            onPressed: () {
              SocketService.loveTouch();
              _onLove(null);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: _msgs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('💌', style: TextStyle(fontSize: 50)),
                        const SizedBox(height: 12),
                        const Text(
                          'Chưa có tin nhắn nào',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF2D3142)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hãy gửi tin nhắn đầu tiên cho người ấy nhé!',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _msgs.length,
                    itemBuilder: (context, i) => _buildChatBubble(_msgs[i]),
                  ),
          ),

          // Message Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.favorite_border_rounded, color: Color(0xFFFF5277)),
                    onPressed: () => SocketService.loveTouch(),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F5FF),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF0E6F7)),
                      ),
                      child: TextField(
                        controller: _msgCtrl,
                        onChanged: (v) => SocketService.typing(v.isNotEmpty),
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          hintText: 'Nhắn điều ngọt ngào...',
                          hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF758C), Color(0xFFFF5277)],
                      ),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> m) {
    final timeStr = m['created_at'];
    final time = timeStr != null ? DateTime.tryParse(timeStr) ?? DateTime.now() : DateTime.now();
    final content = m['content'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF85A2), Color(0xFFFF5277)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF5277).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                content,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500, height: 1.3),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat.Hm().format(time),
                style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
