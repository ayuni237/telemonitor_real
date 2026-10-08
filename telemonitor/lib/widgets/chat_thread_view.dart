import 'package:flutter/material.dart';

import '../models/message.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/presence_service.dart';
import '../theme/app_theme.dart';

/// The live message thread for one patient, plus the input bar.
///
/// Used by BOTH sides. "Mine" is decided by comparing the signed-in uid
/// to each message's senderId rather than by role, so each party sees
/// their own messages on the right.
///
/// Opening the thread marks the other party's messages as read, which is
/// what turns their single tick into a double tick.
class ChatThreadView extends StatefulWidget {
  final String patientId;

  const ChatThreadView({super.key, required this.patientId});

  @override
  State<ChatThreadView> createState() => _ChatThreadViewState();
}

class _ChatThreadViewState extends State<ChatThreadView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    // Having the chat open counts as being online.
    PresenceService.instance.start();
  }

  @override
  void dispose() {
    PresenceService.instance.stop();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    // Deferred to the next frame: when a new message arrives the list has
    // not laid out yet, so maxScrollExtent is still the old value.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    // Cleared immediately so the field feels responsive; restored below if
    // the send fails, so nothing typed is lost.
    _messageController.clear();

    try {
      await ChatService.instance.send(patientId: widget.patientId, text: text);
    } catch (e) {
      if (!mounted) return;
      _messageController.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = AuthService.instance.currentProfile?.uid;

    return Container(
      color: AppColors.background(context),
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: ChatService.instance.watchMessages(widget.patientId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _centered('Could not load messages.\n${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return _centered(
                      'No messages yet.\nStart the conversation below.');
                }

                // Mark incoming messages read. Done after the frame so it
                // is not a side effect of building.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ChatService.instance.markRead(widget.patientId, messages);
                });

                if (messages.length != _lastCount) {
                  _lastCount = messages.length;
                  _scrollToBottom();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final isMine = msg.senderId == myUid;
                    final showName = !isMine &&
                        (i == 0 || messages[i - 1].senderId != msg.senderId);
                    return _bubble(msg, isMine, showName);
                  },
                );
              },
            ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _centered(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textMuted(context)),
        ),
      ),
    );
  }

  String _time(DateTime ts) =>
      '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

  /// Delivery indicator for the SENDER's own messages.
  ///
  ///   single grey tick  — saved to the server
  ///   double blue tick  — the other party has opened the thread since
  ///
  /// A message still queued offline has no server timestamp yet; that
  /// case shows a clock, since it has not actually been sent.
  Widget _ticks(Message msg) {
    if (msg.id == null) {
      return Icon(Icons.schedule,
          size: 12, color: AppColors.textMuted(context));
    }
    if (msg.isRead) {
      return const Icon(Icons.done_all, size: 14, color: Color(0xFF4FC3F7));
    }
    return Icon(Icons.done, size: 14, color: AppColors.textMuted(context));
  }

  Widget _bubble(Message msg, bool isMine, bool showName) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showName)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Text(
                msg.senderName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
          Row(
            mainAxisAlignment:
                isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    // Own messages stay brand navy in both themes; the
                    // other party's use the themed card surface.
                    color: isMine ? AppColors.primary : AppColors.card(context),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMine ? 16 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 16),
                    ),
                    border: isMine
                        ? null
                        : Border.all(
                            color: AppColors.border(context), width: 0.5),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: isMine
                          ? Colors.white
                          : AppColors.textPrimary(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _time(msg.timestamp),
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textMuted(context)),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  _ticks(msg),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        border: Border(
          top: BorderSide(color: AppColors.border(context), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                // Explicit text colour — see the note in edit_profile_screen.
                style: TextStyle(
                    fontSize: 14, color: AppColors.textPrimary(context)),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                      color: AppColors.textMuted(context), fontSize: 13),
                  filled: true,
                  fillColor: AppColors.field(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _send(),
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _isSending
                      ? AppColors.textMuted(context)
                      : AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
