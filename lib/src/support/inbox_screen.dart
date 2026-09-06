import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/support_models.dart';
import 'conversation_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({
    super.key,
    required this.api,
    required this.user,
    required this.themeMode,
    required this.onCycleTheme,
    required this.onLogout,
  });

  final ApiClient api;
  final SupportUser user;
  final ThemeMode themeMode;
  final VoidCallback onCycleTheme;
  final Future<void> Function() onLogout;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with WidgetsBindingObserver {
  final _search = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _events;
  Timer? _refreshDebounce;
  List<SupportTicket> _tickets = const [];
  bool _loading = true;
  String? _error;
  String _filter = 'Open';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _events = widget.api.supportEvents().listen((event) {
      if (event['type'] == 'keepalive' || event['type'] == 'connected') return;
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 250), () => _refresh(silent: true));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    _events?.cancel();
    _refreshDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh(silent: true);
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final items = await widget.api.loadTickets();
      if (!mounted) return;
      setState(() {
        _tickets = items;
        _error = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not refresh support inbox.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<SupportTicket> get _visibleTickets {
    final query = _search.text.trim().toLowerCase();
    return _tickets.where((ticket) {
      final filterOk = switch (_filter) {
        'Mine' => ticket.assignedTo?.toLowerCase() == widget.user.email.toLowerCase(),
        'Unassigned' => ticket.assignedTo == null || ticket.assignedTo!.isEmpty,
        'Open' => ticket.isOpen,
        'Resolved' => ticket.status == 'RESOLVED' || ticket.status == 'CLOSED',
        _ => true,
      };
      if (!filterOk) return false;
      if (query.isEmpty) return true;
      final haystack = [
        ticket.reference,
        ticket.subject,
        ticket.openedBy ?? '',
        ticket.email ?? '',
        ticket.phoneNumber ?? '',
        ticket.tenantName ?? '',
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  Future<void> _openTicket(SupportTicket ticket) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(api: widget.api, user: widget.user, initialTicket: ticket),
      ),
    );
    await _refresh(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = _visibleTickets;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset('assets/arofi_app_icon.png', width: 34, height: 34, fit: BoxFit.cover),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AroFi Support', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text('Live agent inbox', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Theme: ${widget.themeMode.name}',
            onPressed: widget.onCycleTheme,
            icon: Icon(switch (widget.themeMode) {
              ThemeMode.light => Icons.light_mode_outlined,
              ThemeMode.dark => Icons.dark_mode_outlined,
              ThemeMode.system => Icons.brightness_auto_outlined,
            }),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            onSelected: (value) {
              if (value == 'logout') widget.onLogout();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.user.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(widget.user.email, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout), title: Text('Sign out'))),
            ],
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: CircleAvatar(
                radius: 17,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  _initials(widget.user.displayName),
                  style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search name, phone, email or ticket…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _search.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['Open', 'Mine', 'Unassigned', 'All', 'Resolved']
                            .map(
                              (label) => Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: ChoiceChip(
                                  label: Text(label),
                                  selected: _filter == label,
                                  onSelected: (_) => setState(() => _filter = label),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Material(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_off, color: scheme.onErrorContainer),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer))),
                          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_loading && _tickets.isEmpty)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inbox_outlined, size: 54, color: scheme.outline),
                        const SizedBox(height: 12),
                        const Text('No conversations here', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                        const SizedBox(height: 4),
                        const Text('New live chats appear here instantly.', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                sliver: SliverList.separated(
                  itemCount: visible.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 8),
                  itemBuilder: (_, index) => _TicketCard(
                    ticket: visible[index],
                    currentEmail: widget.user.email,
                    onTap: () => _openTicket(visible[index]),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: _refresh,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).take(2).toList();
    if (parts.isEmpty) return 'AS';
    return parts.map((e) => e[0].toUpperCase()).join();
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.currentEmail, required this.onTap});
  final SupportTicket ticket;
  final String currentEmail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final last = ticket.lastMessage;
    final mine = ticket.assignedTo?.toLowerCase() == currentEmail.toLowerCase();
    final unassigned = ticket.assignedTo == null || ticket.assignedTo!.isEmpty;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _priorityColor(ticket.priority).withValues(alpha: .12),
                child: Icon(ticket.isLiveChat ? Icons.forum_outlined : Icons.support_agent, color: _priorityColor(ticket.priority), size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ticket.openedBy?.isNotEmpty == true ? ticket.openedBy! : ticket.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                        Text(_relativeTime(ticket.sortTime), style: TextStyle(fontSize: 10.5, color: theme.colorScheme.outline)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ticket.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    if (last != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        last.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, height: 1.35, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        _MiniBadge(label: ticket.isLiveChat ? 'LIVE CHAT' : ticket.channel, color: const Color(0xFF22A53A)),
                        _MiniBadge(label: ticket.status.replaceAll('_', ' '), color: _statusColor(ticket.status)),
                        if (mine) const _MiniBadge(label: 'MINE', color: Color(0xFF2563EB)),
                        if (unassigned) const _MiniBadge(label: 'UNASSIGNED', color: Color(0xFFD97706)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Color _priorityColor(String priority) => switch (priority) {
        'CRITICAL' => const Color(0xFFDC2626),
        'HIGH' => const Color(0xFFD97706),
        'LOW' => const Color(0xFF64748B),
        _ => const Color(0xFF22A53A),
      };

  Color _statusColor(String status) => switch (status) {
        'RESOLVED' => const Color(0xFF059669),
        'CLOSED' => const Color(0xFF64748B),
        'PENDING_CUSTOMER' => const Color(0xFFD97706),
        'IN_PROGRESS' => const Color(0xFF2563EB),
        _ => const Color(0xFF22A53A),
      };

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time.toLocal());
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('dd MMM').format(time.toLocal());
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: .2)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .2)),
      );
}
