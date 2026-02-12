import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const List<String> _quickPrompts = <String>[
    'Posko terdekat?',
    'Apakah berpotensi tsunami?',
    'Laporkan cedera',
    'Kontak darurat',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send(AppState appState, String text) {
    final value = text.trim();
    if (value.isEmpty) {
      return;
    }
    _controller.clear();
    appState.sendMessage(value);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: <Widget>[
                _HeaderChat(
                  onReset: appState.clearChat,
                  isDark: isDark,
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    itemCount:
                        appState.messages.length + (appState.isSendingMessage ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= appState.messages.length) {
                        return const _TypingItem();
                      }
                      final message = appState.messages[index];
                      return _BubbleItem(message: message);
                    },
                  ),
                ),
                if (!isKeyboardOpen)
                  _ChipsCepat(
                    prompts: _quickPrompts,
                    onTap: (prompt) => _send(appState, prompt),
                  ),
                _InputPesan(
                  controller: _controller,
                  onSend: () => _send(appState, _controller.text),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderChat extends StatelessWidget {
  const _HeaderChat({
    required this.onReset,
    required this.isDark,
  });

  final VoidCallback onReset;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Stack(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(Icons.smart_toy, color: AppTheme.primary),
              ),
              Positioned(
                right: 1,
                bottom: 1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isDark ? AppTheme.surfaceDark : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'AI Darurat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'DATA BMKG LANGSUNG',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset percakapan',
          ),
        ],
      ),
    );
  }
}

class _BubbleItem extends StatelessWidget {
  const _BubbleItem({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final time = DateFormat('HH:mm').format(message.createdAt);
    final align = message.isUser ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: align,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment:
              message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser
                    ? AppTheme.primary
                    : (isDark ? AppTheme.surfaceDark : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 16),
                ),
                border: message.isUser
                    ? null
                    : Border.all(color: isDark ? Colors.white10 : Colors.black12),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: message.isUser
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              time,
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingItem extends StatelessWidget {
  const _TypingItem();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).hintColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).hintColor.withOpacity(0.8),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: Theme.of(context).hintColor.withOpacity(0.6),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipsCepat extends StatelessWidget {
  const _ChipsCepat({
    required this.prompts,
    required this.onTap,
  });

  final List<String> prompts;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemBuilder: (context, index) {
          final prompt = prompts[index];
          final selectedStyle = index == 0;
          return ActionChip(
            onPressed: () => onTap(prompt),
            label: Text(
              prompt,
              style: TextStyle(
                color: selectedStyle
                    ? AppTheme.primary
                    : (isDark ? Colors.white70 : Colors.black54),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: selectedStyle
                ? AppTheme.primary.withOpacity(0.14)
                : (isDark ? AppTheme.surfaceDark : const Color(0xFFF0F0F0)),
            side: BorderSide(
              color: selectedStyle
                  ? AppTheme.primary.withOpacity(0.4)
                  : Colors.transparent,
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: prompts.length,
      ),
    );
  }
}

class _InputPesan extends StatelessWidget {
  const _InputPesan({
    required this.controller,
    required this.onSend,
  });

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fitur kamera akan ditambahkan pada versi berikutnya.'),
                ),
              );
            },
            icon: const Icon(Icons.add_a_photo),
            color: Theme.of(context).hintColor,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3A2226) : const Color(0xFFF1EEEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: const InputDecoration(
                        hintText: 'Ketik pesan...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.mic),
                    color: Theme.of(context).hintColor,
                    tooltip: 'Input suara',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onSend,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
