import 'package:flutter/material.dart';

import '../../services/health_assistant_service.dart';
import '../../theme/app_theme.dart';

class _AssistantMessage {
  final String text;
  final bool fromUser;
  const _AssistantMessage(this.text, {required this.fromUser});
}

/// Conversational assistant for general health questions.
///
/// Deliberately styled so it cannot be mistaken for the clinician chat:
/// a different accent colour, a robot avatar rather than a person, and a
/// banner that names it as automated. A patient who believed they were
/// talking to their doctor might wait for a reply that never comes, or
/// act on general information as though it were personal medical advice.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<_AssistantMessage> _messages = [];
  bool _sending = false;

  /// The assistant's accent — distinct from the clinical navy so the two
  /// conversations never look alike.
  static const Color _accent = Color(0xFF6B4FBB);

  @override
  void initState() {
    super.initState();
    HealthAssistantService.instance.startSession();
    _messages.add(const _AssistantMessage(
      'Hello. I can explain your readings, answer general questions about '
      'blood pressure and diabetes, and help you decide whether something '
      'needs a doctor.\n\n'
      'I cannot advise on medication — only your clinician can do that.',
      fromUser: false,
    ));
  }

  @override
  void dispose() {
    HealthAssistantService.instance.endSession();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_AssistantMessage(text, fromUser: true));
      _sending = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final reply = await HealthAssistantService.instance.send(text);
      if (!mounted) return;
      setState(() => _messages.add(_AssistantMessage(reply, fromUser: false)));
    } on AssistantException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(
            _AssistantMessage(e.message, fromUser: false),
          ));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.smart_toy_outlined,
                    color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Health Assistant',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                Text('Automated — not your doctor',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _disclaimer(),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= _messages.length) return _typingIndicator();
                return _bubble(_messages[i]);
              },
            ),
          ),
          if (_messages.length <= 1 && !_sending) _suggestions(),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _disclaimer() {
    return Container(
      width: double.infinity,
      color: _accent.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 15, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'General information only. It cannot diagnose you or advise '
              'on medication. For anything urgent, go to a health facility.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: HealthAssistantService.suggestedQuestions.map((q) {
          return Material(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _send(q),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _accent.withValues(alpha: 0.4), width: 0.8),
                ),
                child: Text(
                  q,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _bubble(_AssistantMessage m) {
    final mine = m.fromUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.smart_toy_outlined, size: 15, color: _accent),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.74,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: mine ? _accent : AppColors.card(context),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(mine ? 16 : 4),
                  bottomRight: Radius.circular(mine ? 4 : 16),
                ),
                border: mine
                    ? null
                    : Border.all(
                        color: AppColors.border(context), width: 0.5),
              ),
              child: Text(
                m.text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color:
                      mine ? Colors.white : AppColors.textPrimary(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.smart_toy_outlined, size: 15, color: _accent),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.border(context), width: 0.5),
            ),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_accent),
              ),
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
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textPrimary(context)),
              decoration: InputDecoration(
                hintText: 'Ask a health question...',
                hintStyle: TextStyle(
                    color: AppColors.textMuted(context), fontSize: 13),
                filled: true,
                fillColor: AppColors.field(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              onSubmitted: _send,
              maxLines: null,
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _send(_controller.text),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _sending ? AppColors.textMuted(context) : _accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
