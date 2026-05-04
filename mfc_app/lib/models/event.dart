import 'user.dart';

class RSVP {
  final User user;
  final String status; // going, maybe, not_going
  final String? note;
  final DateTime updatedAt;

  RSVP({required this.user, required this.status, this.note, required this.updatedAt});

  factory RSVP.fromJson(Map<String, dynamic> json) => RSVP(
    user: User.fromJson(json['user'] as Map<String, dynamic>),
    status: json['status'] as String,
    note: json['note'] as String?,
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );
}

class Event {
  final int id;
  final String title;
  final String? description;
  final String? location;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String eventType; // trening, turnaj, sraz, jine
  final List<RSVP> rsvps;
  final int goingCount;
  final int maybeCount;
  final String? myStatus;

  Event({
    required this.id,
    required this.title,
    this.description,
    this.location,
    required this.startsAt,
    this.endsAt,
    required this.eventType,
    required this.rsvps,
    required this.goingCount,
    required this.maybeCount,
    this.myStatus,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
    id: json['id'] as int,
    title: json['title'] as String,
    description: json['description'] as String?,
    location: json['location'] as String?,
    startsAt: DateTime.parse(json['starts_at'] as String),
    endsAt: json['ends_at'] != null ? DateTime.parse(json['ends_at']) : null,
    eventType: json['event_type'] as String? ?? 'jine',
    rsvps: (json['rsvps'] as List? ?? []).map((r) => RSVP.fromJson(r as Map<String, dynamic>)).toList(),
    goingCount: json['going_count'] as int? ?? 0,
    maybeCount: json['maybe_count'] as int? ?? 0,
    myStatus: json['my_status'] as String?,
  );

  String get typeLabel {
    switch (eventType) {
      case 'trening': return 'Trénink';
      case 'turnaj':  return 'Turnaj';
      case 'sraz':    return 'Sraz';
      default:        return 'Akce';
    }
  }
}
