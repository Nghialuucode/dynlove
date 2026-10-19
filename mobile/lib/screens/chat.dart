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
      setState(() => _partnerTyping = d['typing'] == true ? '⌨️ đang nhập...' : null);
      if (d['typing'] == true) {
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _partnerTyping = null);
        });
      }
    }
  }

  void _onLove(dynamic _) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💗 Người ấy vừa gửi yêu thương! 💗'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    SocketService.sendMessage(text);
    _msgCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Trò chuyện 💬'),
            if (_partnerTyping != null)
              Text(_partnerTyping!, style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.pink),
            onPressed: () => SocketService.loveTouch(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: _msgs.length,
              itemBuilder: (context, i) => _bubble(_msgs[i]),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      onChanged: (v) => SocketService.typing(v.isNotEmpty),
                      decoration: const InputDecoration(
                        hintText: 'Nhắn gì đó...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24))),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.pink,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
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

  Widget _bubble(Map<String, dynamic> m) {
    final isMe = m['sender_id'] != null; // đơn giản: tô hết màu hồng
    final timeStr = m['created_at'];
    final time = timeStr != null ? DateTime.tryParse(timeStr) ?? DateTime.now() : DateTime.now();
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isMe ? Colors.pink.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(m['content'] ?? '', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 4),
            Text(DateFormat.Hm().format(time),
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
