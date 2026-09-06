import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../models/support_models.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.api,
    required this.user,
    required this.initialTicket,
  });

  final ApiClient api;
  final SupportUser user;
  final SupportTicket initialTicket;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  final _recorder = AudioRecorder();
  StreamSubscription<Map<String, dynamic>>? _events;
  Timer? _refreshDebounce;
  Timer? _recordTimer;
  late SupportTicket _ticket;
  bool _sending = false;
  bool _recording = false;
  Duration _recordDuration = Duration.zero;
  bool _internalNote = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ticket = widget.initialTicket;
    _events = widget.api.supportEvents().listen((event) {
      final id = event['ticketId']?.toString();
      if (id != _ticket.id) return;
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 180), _refreshTicket);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    _events?.cancel();
    _refreshDebounce?.cancel();
    _recordTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _refreshTicket() async {
    try {
      final tickets = await widget.api.loadTickets();
      final updated = tickets.where((item) => item.id == _ticket.id).firstOrNull;
      if (updated != null && mounted) {
        setState(() => _ticket = updated);
        WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom(animated: true));
      }
    } catch (_) {
      // Realtime refresh failures should not interrupt the active conversation.
    }
  }

  Future<void> _sendText() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final updated = await widget.api.sendMessage(_ticket.id, text, isInternal: _internalNote);
      if (!mounted) return;
      setState(() {
        _ticket = updated;
        _composer.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom(animated: true));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send message.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAttachment() async {
    if (_sending) return;
    final result = await FilePicker.platform.pickFiles(withData: false, allowMultiple: false);
    final path = result?.files.single.path;
    if (path == null) return;
    await _upload(path);
  }

  Future<void> _upload(String path, {String? body, String? mimeType}) async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final updated = await widget.api.uploadAttachment(
        _ticket.id,
        path,
        body: body,
        isInternal: _internalNote,
        mimeType: mimeType,
      );
      if (!mounted) return;
      setState(() => _ticket = updated);
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom(animated: true));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not upload attachment.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_sending) return;
    if (_recording) {
      await _finishRecording();
      return;
    }
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission is required for voice messages.')));
      }
      return;
    }
    final temp = await getTemporaryDirectory();
    final path = '${temp.path}${Platform.pathSeparator}arofi_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000, sampleRate: 44100),
      path: path,
    );
    _recordTimer?.cancel();
    setState(() {
      _recording = true;
      _recordDuration = Duration.zero;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordDuration += const Duration(seconds: 1));
    });
  }

  Future<void> _finishRecording() async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    if (mounted) setState(() => _recording = false);
    if (path != null) await _upload(path, body: 'Voice message', mimeType: 'audio/mp4');
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    await _recorder.cancel();
    if (mounted) {
      setState(() {
        _recording = false;
        _recordDuration = Duration.zero;
      });
    }
  }

  Future<void> _showTransfer() async {
    if (!widget.user.canWriteSupport) return;
    List<SupportAgent> staff;
    try {
      staff = await widget.api.loadStaff();
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (!mounted) return;
    final selected = await showModalBottomSheet<SupportAgent?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .72),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text('Transfer conversation', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_off_outlined)),
                title: const Text('Unassign'),
                subtitle: const Text('Return this chat to the shared inbox'),
                onTap: () => Navigator.pop(context, const SupportAgent(id: '', email: '', displayName: '', role: '')),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: staff.length,
                  itemBuilder: (_, index) {
                    final agent = staff[index];
                    final selectedNow = agent.email.toLowerCase() == _ticket.assignedTo?.toLowerCase();
                    return ListTile(
                      leading: CircleAvatar(child: Text(_initials(agent.displayName))),
                      title: Text(agent.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${agent.role} · ${agent.email}'),
                      trailing: selectedNow ? const Icon(Icons.check_circle, color: Color(0xFF22A53A)) : null,
                      onTap: () => Navigator.pop(context, agent),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    await _setAssignee(selected.id.isEmpty ? null : selected.id);
  }

  Future<void> _setAssignee(String? userId) async {
    setState(() => _sending = true);
    try {
      final updated = await widget.api.updateTicket(_ticket.id, assigneeUserId: userId, includeAssignee: true);
      if (mounted) setState(() => _ticket = updated);
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _claim() => _setAssignee(widget.user.id);

  Future<void> _changeStatus(String status) async {
    setState(() => _sending = true);
    try {
      final updated = await widget.api.updateTicket(_ticket.id, status: status);
      if (mounted) setState(() => _ticket = updated);
    } on ApiException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _jumpToBottom({bool animated = false}) {
    if (!_scroll.hasClients) return;
    final target = _scroll.position.maxScrollExtent;
    if (animated) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final unassigned = _ticket.assignedTo == null || _ticket.assignedTo!.isEmpty;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _ticket.openedBy?.isNotEmpty == true ? _ticket.openedBy! : _ticket.subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              '${_ticket.reference} · ${_ticket.isLiveChat ? 'Live chat' : _ticket.channel}',
              style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          if (unassigned && widget.user.canWriteSupport)
            TextButton.icon(onPressed: _sending ? null : _claim, icon: const Icon(Icons.person_add_alt_1, size: 17), label: const Text('Claim')),
          PopupMenuButton<String>(
            tooltip: 'Conversation actions',
            onSelected: (value) {
              if (value == 'transfer') {
                _showTransfer();
              } else if (value.startsWith('status:')) {
                _changeStatus(value.substring(7));
              }
            },
            itemBuilder: (_) => [
              if (widget.user.canWriteSupport)
                const PopupMenuItem(value: 'transfer', child: ListTile(leading: Icon(Icons.swap_horiz), title: Text('Transfer'))),
              const PopupMenuDivider(),
              ...['OPEN', 'IN_PROGRESS', 'PENDING_CUSTOMER', 'RESOLVED', 'CLOSED'].map(
                (status) => PopupMenuItem(
                  value: 'status:$status',
                  child: ListTile(
                    leading: Icon(status == _ticket.status ? Icons.radio_button_checked : Icons.radio_button_off),
                    title: Text(_prettyStatus(status)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _ConversationInfo(ticket: _ticket),
          if (_error != null)
            Container(
              width: double.infinity,
              color: scheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer, fontSize: 12))),
                  IconButton(onPressed: () => setState(() => _error = null), icon: const Icon(Icons.close, size: 18)),
                ],
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshTicket,
              child: ListView.builder(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                itemCount: _ticket.messages.length,
                itemBuilder: (_, index) {
                  final message = _ticket.messages[index];
                  return _MessageBubble(message: message, api: widget.api);
                },
              ),
            ),
          ),
          if (_recording)
            _RecordingBar(
              duration: _recordDuration,
              onCancel: _cancelRecording,
              onSend: _finishRecording,
            )
          else
            _Composer(
              controller: _composer,
              internalNote: _internalNote,
              busy: _sending,
              canWrite: widget.user.canWriteSupport,
              onInternalChanged: (value) => setState(() => _internalNote = value),
              onAttach: _pickAttachment,
              onMic: _toggleRecording,
              onSend: _sendText,
            ),
        ],
      ),
    );
  }

  static String _prettyStatus(String status) => status.toLowerCase().replaceAll('_', ' ').split(' ').map((e) => '${e[0].toUpperCase()}${e.substring(1)}').join(' ');
  static String _initials(String value) => value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(2).map((e) => e[0].toUpperCase()).join();
}

class _ConversationInfo extends StatelessWidget {
  const _ConversationInfo({required this.ticket});
  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final details = [
      if (ticket.tenantName?.isNotEmpty == true) ticket.tenantName!,
      if (ticket.email?.isNotEmpty == true) ticket.email!,
      if (ticket.phoneNumber?.isNotEmpty == true) ticket.phoneNumber!,
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 11),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          _StatusPill(status: ticket.status),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              details.isEmpty ? ticket.subject : details.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ),
          if (ticket.assignee != null)
            Tooltip(
              message: 'Assigned to ${ticket.assignee!.displayName}',
              child: Chip(
                avatar: const Icon(Icons.person_outline, size: 15),
                label: Text(ticket.assignee!.displayName, style: const TextStyle(fontSize: 10)),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.api});
  final SupportMessage message;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    if (message.isInternal) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 7),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(10)),
          child: Text('Internal · ${message.authorName}: ${message.body}', style: const TextStyle(color: Color(0xFF8A4F0A), fontSize: 11.5)),
        ),
      );
    }
    final customer = message.fromCustomer;
    final scheme = Theme.of(context).colorScheme;
    final bubbleColor = customer ? scheme.surfaceContainerHighest : const Color(0xFF22A53A);
    final textColor = customer ? scheme.onSurface : Colors.white;
    return Align(
      alignment: customer ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .82),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(customer ? 4 : 14),
              bottomRight: Radius.circular(customer ? 14 : 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.authorName,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: customer ? scheme.primary : Colors.white.withValues(alpha: .8)),
              ),
              if (message.body.isNotEmpty) ...[
                const SizedBox(height: 3),
                Linkify(
                  text: message.body,
                  style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
                  linkStyle: TextStyle(color: customer ? const Color(0xFF2563EB) : Colors.white, decoration: TextDecoration.underline),
                  onOpen: (link) async {
                    final uri = Uri.tryParse(link.url);
                    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              ],
              if (message.attachments.isNotEmpty) ...[
                const SizedBox(height: 7),
                ...message.attachments.map((attachment) => _AttachmentTile(attachment: attachment, api: api, darkOnGreen: !customer)),
              ],
              const SizedBox(height: 5),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  DateFormat('HH:mm').format(message.createdAt.toLocal()),
                  style: TextStyle(fontSize: 9.5, color: customer ? scheme.outline : Colors.white.withValues(alpha: .72)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttachmentTile extends StatefulWidget {
  const _AttachmentTile({required this.attachment, required this.api, required this.darkOnGreen});
  final SupportAttachment attachment;
  final ApiClient api;
  final bool darkOnGreen;

  @override
  State<_AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<_AttachmentTile> {
  final AudioPlayer _player = AudioPlayer();
  bool _busy = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen((state) {
      if (mounted) setState(() => _playing = state.playing);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (widget.attachment.isAudio) {
        if (_playing) {
          await _player.pause();
        } else {
          final url = widget.api.attachmentUrl(widget.attachment.id);
          final cookie = await widget.api.cookieHeaderFor(Uri.parse(url));
          if (_player.audioSource == null) {
            await _player.setUrl(url, headers: cookie.isEmpty ? null : {'Cookie': cookie});
          }
          await _player.play();
        }
      } else {
        final path = await widget.api.downloadAttachment(widget.attachment);
        await OpenFilex.open(path);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foreground = widget.darkOnGreen ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return InkWell(
      onTap: _open,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: widget.darkOnGreen ? Colors.black.withValues(alpha: .12) : Theme.of(context).colorScheme.surface.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: foreground.withValues(alpha: .14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy)
              SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: foreground))
            else
              Icon(widget.attachment.isAudio ? (_playing ? Icons.pause : Icons.play_arrow) : Icons.attach_file, size: 18, color: foreground),
            const SizedBox(width: 7),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.attachment.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: foreground, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  Text(_formatBytes(widget.attachment.fileSize), style: TextStyle(color: foreground.withValues(alpha: .72), fontSize: 9.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.internalNote,
    required this.busy,
    required this.canWrite,
    required this.onInternalChanged,
    required this.onAttach,
    required this.onMic,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool internalNote;
  final bool busy;
  final bool canWrite;
  final ValueChanged<bool> onInternalChanged;
  final VoidCallback onAttach;
  final VoidCallback onMic;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
        decoration: BoxDecoration(color: scheme.surface, border: Border(top: BorderSide(color: scheme.outlineVariant))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canWrite)
              Row(
                children: [
                  FilterChip(
                    label: const Text('Internal note', style: TextStyle(fontSize: 10.5)),
                    selected: internalNote,
                    onSelected: busy ? null : onInternalChanged,
                    avatar: const Icon(Icons.lock_outline, size: 14),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(onPressed: busy || !canWrite ? null : onAttach, icon: const Icon(Icons.attach_file), tooltip: 'Attach file'),
                IconButton(onPressed: busy || !canWrite ? null : onMic, icon: const Icon(Icons.mic_none), tooltip: 'Voice message'),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: canWrite && !busy,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: internalNote ? 'Internal note…' : 'Message customer…',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 7),
                IconButton.filled(
                  onPressed: busy || !canWrite ? null : onSend,
                  icon: busy
                      ? const SizedBox.square(dimension: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  tooltip: 'Send',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({required this.duration, required this.onCancel, required this.onSend});
  final Duration duration;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              const Icon(Icons.fiber_manual_record, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Recording ${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(onPressed: onCancel, icon: const Icon(Icons.delete_outline), label: const Text('Cancel')),
              const SizedBox(width: 6),
              FilledButton.icon(onPressed: onSend, icon: const Icon(Icons.send), label: const Text('Send')),
            ],
          ),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'RESOLVED' => const Color(0xFF059669),
      'CLOSED' => const Color(0xFF64748B),
      'PENDING_CUSTOMER' => const Color(0xFFD97706),
      'IN_PROGRESS' => const Color(0xFF2563EB),
      _ => const Color(0xFF22A53A),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .09), borderRadius: BorderRadius.circular(999)),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
