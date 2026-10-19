import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api.dart';

class SocketService {
  static io.Socket? _socket;
  static final Map<String, List<Function(dynamic)>> _handlers = {};

  static void connect() {
    if (_socket?.connected == true) return;
    _socket = io.io(
      Api.base,
      io.OptionBuilder()
        .setTransports(['websocket'])
        .setAuth({'token': Api.token})
        .disableAutoConnect()
        .build(),
    );
    _socket!.connect();

    _socket!.onConnect((_) => print('✅ socket connected'));
    _socket!.on('chat:new', (d) => _emit('chat:new', d));
    _socket!.on('chat:typing', (d) => _emit('chat:typing', d));
    _socket!.on('pet:update', (d) => _emit('pet:update', d));
    _socket!.on('love:touch', (d) => _emit('love:touch', d));
  }

  static void _emit(String ev, dynamic d) {
    _handlers[ev]?.forEach((h) => h(d));
  }

  static void on(String ev, Function(dynamic) h) {
    _handlers.putIfAbsent(ev, () => []).add(h);
  }

  static void off(String ev, Function(dynamic) h) {
    _handlers[ev]?.remove(h);
  }

  static void sendMessage(String content) =>
    _socket?.emit('chat:send', {'content': content});

  static void typing(bool t) => _socket?.emit('chat:typing', {'typing': t});

  static void loveTouch() => _socket?.emit('love:touch');

  static void disconnect() => _socket?.disconnect();
}
