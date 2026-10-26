import 'package:flutter/material.dart';

import '../models/clinical_event.dart';
import '../services/chat_service.dart';
import '../services/events_service.dart';
import '../theme/app_theme.dart';

/// Verdict capture (thesis ch.4 §Clinician dashboard): two or three
/// interactions — true alert, false alert or uncertain, plus the action
/// taken — with an optional comment. Saving closes the event; the comment can
/// also be sent to the patient, which informs them of the review.
Future<bool> showVerdictSheet(BuildContext context, ClinicalEvent event) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card(context),
    builder: (_) => _VerdictSheet(event: event),
  );
  return saved ?? false;
}

class _VerdictSheet extends StatefulWidget {
  final ClinicalEvent event;
  const _VerdictSheet({required this.event});

  @override
  State<_VerdictSheet> createState() => _VerdictSheetState();
}

class _VerdictSheetState extends State<_VerdictSheet> {
  Verdict? _verdict;
  ClinicalAction _action = ClinicalAction.none;
  final _comment = TextEditingController();
  bool _tellPatient = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final v = _verdict;
    if (v == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      EventsService.instance.recordVerdict(widget.event, verdict: v, action: _action, comment: _comment.text);
      if (_tellPatient && _comment.text.trim().isNotEmpty) {
        await ChatService.instance.send(patientId: widget.event.patientId, text: _comment.text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save the verdict: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = TextStyle(
        fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryText(context));
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verdict', style: label.copyWith(fontSize: 15)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final v in Verdict.values)
                ChoiceChip(
                  label: Text(v.label),
                  selected: _verdict == v,
                  onSelected: (_) => setState(() => _verdict = v),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Action taken', style: label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final a in ClinicalAction.values)
                ChoiceChip(
                  label: Text(a.label),
                  selected: _action == a,
                  onSelected: (_) => setState(() => _action = a),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _comment,
            maxLines: 2,
            maxLength: 1000,
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
            decoration: const InputDecoration(hintText: 'Comment (optional) — serves as the clinical note'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _tellPatient,
            onChanged: (v) => setState(() => _tellPatient = v ?? false),
            title: const Text('Send the comment to the patient', style: TextStyle(fontSize: 13)),
          ),
          if (_error != null)
            Text(_error!, style: TextStyle(fontSize: 12, color: AppColors.dangerText(context))),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _verdict == null || _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Close the alert'),
            ),
          ),
        ],
      ),
    );
  }
}
