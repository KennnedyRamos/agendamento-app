import 'package:agendamento_app/app/models/chat_conversation.dart';
import 'package:agendamento_app/app/services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final ChatConversation conversation;

  const ChatPage({super.key, required this.conversation});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocus = FocusNode();
  bool _sending = false;

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  bool get _isBarber => _currentUserId == widget.conversation.barberId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = _currentUserId;
      if (userId != null) {
        _chatService.markConversationNotificationsAsRead(
          userId: userId,
          conversationId: widget.conversation.id,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      await _chatService.sendMessage(
        conversation: widget.conversation,
        text: text,
      );
      _messageController.clear();
      _messageFocus.requestFocus();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível enviar: $error')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final counterpart = _isBarber
        ? widget.conversation.clientName
        : widget.conversation.barbershopName;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              counterpart,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              _isBarber ? 'Cliente' : 'Barbearia',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.watchMessages(widget.conversation.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const _ChatState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Conversa indisponível',
                    message: 'Confira sua conexão e tente novamente.',
                  );
                }

                final messages = snapshot.data ?? const <ChatMessage>[];
                if (messages.isEmpty) {
                  return _ChatState(
                    icon: Icons.forum_outlined,
                    title: _isBarber
                        ? 'Nenhuma mensagem ainda'
                        : 'Fale com a barbearia',
                    message: _isBarber
                        ? 'Quando o cliente escrever, a conversa aparecerá aqui.'
                        : 'Envie sua dúvida sobre serviços, horários ou atendimento.',
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _MessageBubble(
                      message: message,
                      mine: message.senderId == _currentUserId,
                    );
                  },
                );
              },
            ),
          ),
          Material(
            color: colors.surfaceContainerLowest,
            elevation: 8,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocus,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 1000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Digite uma mensagem',
                        counterText: '',
                        filled: true,
                        fillColor: colors.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    tooltip: 'Enviar',
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
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

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;

  const _MessageBubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final time = message.createdAt == null
        ? 'Agora'
        : DateFormat('HH:mm').format(message.createdAt!);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 7),
        decoration: BoxDecoration(
          color: mine ? colors.primary : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: mine ? colors.onPrimary : colors.onSurface,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              time,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: mine
                        ? colors.onPrimary.withValues(alpha: 0.72)
                        : colors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _ChatState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: colors.primaryContainer,
              child: Icon(icon, color: colors.onPrimaryContainer, size: 30),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
