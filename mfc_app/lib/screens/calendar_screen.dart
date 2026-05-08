import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../models/event.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../widgets/avatar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  List<Event>? _events;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await context.read<ApiClient>().get('/events');
      setState(() {
        _events = (res as List).map((j) => Event.fromJson(j as Map<String, dynamic>)).toList();
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _newEvent() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _NewEventScreen()),
    );
    if (result == true) _load();
  }

  Future<void> _setRSVP(Event e, String status) async {
    try {
      final updated = await context.read<ApiClient>().post('/events/${e.id}/rsvp', {'status': status});
      final newEvent = Event.fromJson(updated as Map<String, dynamic>);
      setState(() {
        final idx = _events!.indexWhere((x) => x.id == e.id);
        if (idx != -1) _events![idx] = newEvent;
      });
    } catch (err) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba: $err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kalendář'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: _newEvent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(color: AppTheme.primary, onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppTheme.danger)));
    }
    if (_events == null) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_events!.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 120),
        Icon(Icons.event_busy, size: 64, color: AppTheme.textMuted),
        SizedBox(height: 12),
        Center(child: Text('Žádné nadcházející akce', style: TextStyle(color: AppTheme.textMuted))),
      ]);
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _events!.length,
      itemBuilder: (_, i) => _EventCard(event: _events![i], onRSVP: (s) => _setRSVP(_events![i], s)),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final void Function(String status) onRSVP;
  const _EventCard({required this.event, required this.onRSVP});

  Color get _typeColor {
    switch (event.eventType) {
      case 'turnaj':  return Colors.amber;
      case 'trening': return AppTheme.primary;
      case 'sraz':    return Colors.blue;
      default:        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEEE d.M. HH:mm', 'cs');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _EventDetailScreen(event: event, onRSVP: onRSVP)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _typeColor.withOpacity(.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(event.typeLabel, style: TextStyle(color: _typeColor, fontWeight: FontWeight.w600, fontSize: 11)),
                  ),
                  const Spacer(),
                  if (event.myStatus == 'going') const _StatusChip(label: 'Jdu', color: AppTheme.success),
                  if (event.myStatus == 'maybe') const _StatusChip(label: 'Možná', color: AppTheme.warning),
                  if (event.myStatus == 'not_going') const _StatusChip(label: 'Nejdu', color: AppTheme.danger),
                ],
              ),
              const SizedBox(height: 10),
              Text(event.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.access_time, size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(df.format(event.startsAt), style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              ]),
              if (event.location != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.place_outlined, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Expanded(child: Text(event.location!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13))),
                ]),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  _RSVPButton(label: 'Jdu (${event.goingCount})', selected: event.myStatus == 'going',
                    onTap: () => onRSVP('going'), color: AppTheme.success),
                  const SizedBox(width: 6),
                  _RSVPButton(label: 'Možná (${event.maybeCount})', selected: event.myStatus == 'maybe',
                    onTap: () => onRSVP('maybe'), color: AppTheme.warning),
                  const SizedBox(width: 6),
                  _RSVPButton(label: 'Nejdu', selected: event.myStatus == 'not_going',
                    onTap: () => onRSVP('not_going'), color: AppTheme.danger),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RSVPButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  const _RSVPButton({required this.label, required this.selected, required this.onTap, required this.color});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(.2) : Colors.transparent,
            border: Border.all(color: selected ? color : AppTheme.border),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(
            color: selected ? color : AppTheme.text,
            fontSize: 12, fontWeight: FontWeight.w600,
          )),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(.2), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _EventDetailScreen extends StatefulWidget {
  final Event event;
  final void Function(String status) onRSVP;
  const _EventDetailScreen({required this.event, required this.onRSVP});

  @override
  State<_EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<_EventDetailScreen> {
  late Event _event;

  @override
  void initState() {
    super.initState();
    _event = widget.event;
  }

  Color get _typeColor {
    switch (_event.eventType) {
      case 'turnaj':  return Colors.amber;
      case 'trening': return AppTheme.primary;
      case 'sraz':    return Colors.blue;
      default:        return AppTheme.textMuted;
    }
  }

  Future<void> _setRSVP(String status) async {
    try {
      final updated = await context.read<ApiClient>().post(
        '/events/${_event.id}/rsvp', {'status': status},
      );
      final newEvent = Event.fromJson(updated as Map<String, dynamic>);
      setState(() => _event = newEvent);
      widget.onRSVP(status); // notify parent list to update
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chyba: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  Future<void> _openMaps() async {
    if (_event.location == null) return;
    final encoded = Uri.encodeComponent(_event.location!);
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nelze otevřít mapy')),
      );
    }
  }

  Future<void> _shareICS() async {
    final ics = _buildIcs(_event);
    await Clipboard.setData(ClipboardData(text: ics));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ICS zkopírován do schránky — vlož do kalendáře'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  String _buildIcs(Event e) {
    String fmt(DateTime dt) =>
        '${dt.toUtc().toIso8601String().replaceAll(RegExp(r"[-:]"), "").substring(0, 15)}Z';
    final end = e.endsAt ?? e.startsAt.add(const Duration(hours: 2));
    return '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//MFC Vysocina//mfc-app//CS
BEGIN:VEVENT
UID:mfc-${e.id}@mfc-vysocina
DTSTART:${fmt(e.startsAt)}
DTEND:${fmt(end)}
SUMMARY:${e.title}
DESCRIPTION:${(e.description ?? '').replaceAll('\n', '\\n')}
LOCATION:${e.location ?? ''}
END:VEVENT
END:VCALENDAR''';
  }

  @override
  Widget build(BuildContext context) {
    final goingList = _event.rsvps.where((r) => r.status == 'going').toList();
    final maybeList = _event.rsvps.where((r) => r.status == 'maybe').toList();
    final notGoingList = _event.rsvps.where((r) => r.status == 'not_going').toList();
    final df = DateFormat('EEEE d. MMMM y, HH:mm', 'cs');

    return Scaffold(
      appBar: AppBar(
        title: Text(_event.typeLabel),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Přidat do kalendáře',
            onPressed: _shareICS,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_typeIcon, size: 14, color: _typeColor),
                const SizedBox(width: 6),
                Text(_event.typeLabel.toUpperCase(),
                  style: TextStyle(color: _typeColor, fontWeight: FontWeight.w700, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(_event.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          // Datum
          _InfoRow(
            icon: Icons.access_time,
            label: 'Začátek',
            value: df.format(_event.startsAt),
          ),
          if (_event.endsAt != null) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.timer_off_outlined,
              label: 'Konec',
              value: df.format(_event.endsAt!),
            ),
          ],
          // Misto + tlacitko Mapy
          if (_event.location != null) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: _openMaps,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 18, color: AppTheme.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Místo', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                          Text(_event.location!, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _openMaps,
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('Otevřít v mapách'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Popis
          if (_event.description != null && _event.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(_event.description!, style: const TextStyle(fontSize: 15, height: 1.4)),
            ),
          ],

          const SizedBox(height: 20),

          // RSVP velka tlacitka
          const Text('Jdeš?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _BigRSVPButton(label: '✓ Jdu',  count: _event.goingCount, color: AppTheme.success, selected: _event.myStatus == 'going',     onTap: () => _setRSVP('going'))),
            const SizedBox(width: 8),
            Expanded(child: _BigRSVPButton(label: '? Možná', count: _event.maybeCount, color: AppTheme.warning, selected: _event.myStatus == 'maybe',     onTap: () => _setRSVP('maybe'))),
            const SizedBox(width: 8),
            Expanded(child: _BigRSVPButton(label: '✗ Nejdu', count: notGoingList.length, color: AppTheme.danger,  selected: _event.myStatus == 'not_going', onTap: () => _setRSVP('not_going'))),
          ]),

          const SizedBox(height: 24),

          // Seznamy
          if (goingList.isNotEmpty) _RSVPGroup(label: 'Jdou', color: AppTheme.success, rsvps: goingList),
          if (maybeList.isNotEmpty) _RSVPGroup(label: 'Možná', color: AppTheme.warning, rsvps: maybeList),
          if (notGoingList.isNotEmpty) _RSVPGroup(label: 'Nejdou', color: AppTheme.danger, rsvps: notGoingList),
        ],
      ),
    );
  }

  IconData get _typeIcon => switch (_event.eventType) {
    'turnaj' => Icons.emoji_events_outlined,
    'trening' => Icons.fitness_center,
    'sraz' => Icons.groups_outlined,
    _ => Icons.event_outlined,
  };
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              Text(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BigRSVPButton extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _BigRSVPButton({required this.label, required this.count, required this.color, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.18) : AppTheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: selected ? color : AppTheme.border, width: selected ? 1.5 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 14)),
              Text('$count', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RSVPGroup extends StatelessWidget {
  final String label;
  final Color color;
  final List<RSVP> rsvps;
  const _RSVPGroup({required this.label, required this.color, required this.rsvps});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('$label (${rsvps.length})',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
              ],
            ),
          ),
          ...rsvps.map((r) => ListTile(
            leading: Avatar(user: r.user, size: 36),
            title: Text(r.user.displayName, style: const TextStyle(fontSize: 14)),
            subtitle: r.note != null ? Text(r.note!, style: const TextStyle(fontSize: 12)) : null,
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          )),
        ],
      ),
    );
  }
}

class _NewEventScreen extends StatefulWidget {
  const _NewEventScreen();
  @override
  State<_NewEventScreen> createState() => _NewEventScreenState();
}

class _NewEventScreenState extends State<_NewEventScreen> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  String _type = 'trening';
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);
  bool _busy = false;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context, initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final dt = DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);
      await context.read<ApiClient>().post('/events', {
        'title': _title.text.trim(),
        'description': _description.text.trim().isEmpty ? null : _description.text.trim(),
        'location': _location.text.trim().isEmpty ? null : _location.text.trim(),
        'starts_at': dt.toIso8601String(),
        'event_type': _type,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chyba: $e')));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nová akce'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _submit,
            child: const Text('Vytvořit', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Název akce *')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Typ'),
            items: const [
              DropdownMenuItem(value: 'trening', child: Text('Trénink')),
              DropdownMenuItem(value: 'turnaj', child: Text('Turnaj')),
              DropdownMenuItem(value: 'sraz', child: Text('Sraz')),
              DropdownMenuItem(value: 'jine', child: Text('Jiné')),
            ],
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(DateFormat('d.M.y').format(_date)))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: _pickTime, icon: const Icon(Icons.access_time, size: 16),
              label: Text(_time.format(context)))),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _location, decoration: const InputDecoration(labelText: 'Místo')),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Popis'),
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}
