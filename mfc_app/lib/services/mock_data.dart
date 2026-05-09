/// Mock data pro preview/dev režim — bez skutečného backendu.
/// Nahraje seedy do Feed/Calendar/Chat/Profile, ať vidíš funkční UI.
class MockData {
  static String _iso(DateTime d) => d.toUtc().toIso8601String();

  static Map<String, dynamic> _user(int id, String username, String role,
      {String? fullName, String? bio, int onlineMinAgo = 999}) {
    return {
      'id': id,
      'username': username,
      'email': '$username@mfc-vysocina.cz',
      'full_name': fullName ?? username,
      'role': role,
      'avatar_url': null,
      'bio': bio,
      'created_at': _iso(DateTime.now().subtract(const Duration(days: 90))),
      'last_seen': _iso(DateTime.now().subtract(Duration(minutes: onlineMinAgo))),
      'is_banned': false,
    };
  }

  static final _users = [
    _user(1, 'preview', 'admin', fullName: 'Preview Uživatel', bio: 'Toto je preview režim — pro vývoj UI bez backendu.', onlineMinAgo: 0),
    _user(2, 'jakub_kapitan', 'captain', fullName: 'Jakub Novák', bio: 'Kapitán týmu, fightuje od 2019', onlineMinAgo: 2),
    _user(3, 'tomas_buhurt', 'member', fullName: 'Tomáš Veselý', onlineMinAgo: 15),
    _user(4, 'martin_squire', 'member', fullName: 'Martin Černý', onlineMinAgo: 120),
    _user(5, 'petra_zbrojir', 'member', fullName: 'Petra Dvořáková', bio: 'Zbrojířka týmu', onlineMinAgo: 45),
  ];

  /// Returns mock data for a GET, or null if path isn't mocked.
  static dynamic get(String path, [Map<String, dynamic>? query]) {
    // Auth
    if (path == '/auth/me') return _users[0];
    if (path == '/auth/me/permissions') {
      return {
        'permissions': [
          'posts.create', 'posts.delete', 'posts.pin',
          'events.create', 'events.delete', 'events.edit',
          'users.manage', 'roles.manage', 'permissions.manage',
          'admin.access',
        ],
      };
    }

    // Feed
    if (path == '/posts') {
      return [
        {
          'id': 1,
          'author': _users[1],
          'content': 'Tým, příští sobotu jedeme na turnaj do Brna! Sraz v 7:00 u haly. Kdo nemá brnění připravené, ať se ozve do středy. Těším se na všechny! ⚔️',
          'image_url': null,
          'pinned': true,
          'created_at': _iso(DateTime.now().subtract(const Duration(hours: 2))),
        },
        {
          'id': 2,
          'author': _users[2],
          'content': 'Včerejší trénink byl masakr 💪 Děkuju všem za nasazení. Nové sestavy 5v5 začínají vyjíždět.',
          'image_url': null,
          'pinned': false,
          'created_at': _iso(DateTime.now().subtract(const Duration(hours: 18))),
        },
        {
          'id': 3,
          'author': _users[4],
          'content': 'Mám novou várku rukavic od Battle Merchant. Komu spravit, hlaste se. Pondělí–pátek u mě v dílně.',
          'image_url': null,
          'pinned': false,
          'created_at': _iso(DateTime.now().subtract(const Duration(days: 1))),
        },
        {
          'id': 4,
          'author': _users[3],
          'content': 'Fotky z minulého srazu uploadnu zítra. Pár dobrých záběrů z té duel session.',
          'image_url': null,
          'pinned': false,
          'created_at': _iso(DateTime.now().subtract(const Duration(days: 3))),
        },
      ];
    }

    // Events
    if (path == '/events') {
      final now = DateTime.now();
      return [
        {
          'id': 1,
          'title': 'Trénink — duely',
          'description': 'Klasický úterní trénink. Přineste si vlastní zbraně, štíty máme na hale.',
          'location': 'Sportovní hala Vysočina, Jihlava',
          'starts_at': _iso(DateTime(now.year, now.month, now.day + 2, 18, 0)),
          'ends_at': _iso(DateTime(now.year, now.month, now.day + 2, 20, 0)),
          'event_type': 'trening',
          'rsvps': [],
          'going_count': 8,
          'maybe_count': 2,
          'my_status': 'going',
        },
        {
          'id': 2,
          'title': 'Turnaj v Brně — Battle of Nations Cup',
          'description': '5v5 + duels. Registrace v 8:00, první boje 9:30. Pojedeme společně dvěma auty, sraz 7:00 u haly.',
          'location': 'Hala Rondo, Brno',
          'starts_at': _iso(DateTime(now.year, now.month, now.day + 7, 9, 30)),
          'ends_at': _iso(DateTime(now.year, now.month, now.day + 7, 18, 0)),
          'event_type': 'turnaj',
          'rsvps': [],
          'going_count': 6,
          'maybe_count': 3,
          'my_status': null,
        },
        {
          'id': 3,
          'title': 'Sraz — strategie a sledování',
          'description': 'Pivo, video z minulého turnaje, debata o sestavách.',
          'location': 'Restaurace U Sokola, Jihlava',
          'starts_at': _iso(DateTime(now.year, now.month, now.day + 4, 19, 0)),
          'ends_at': null,
          'event_type': 'sraz',
          'rsvps': [],
          'going_count': 5,
          'maybe_count': 4,
          'my_status': 'maybe',
        },
        {
          'id': 4,
          'title': 'Trénink — sestavy',
          'description': 'Práce na 5v5 sestavách. Plná zbroj povinná.',
          'location': 'Sportovní hala Vysočina',
          'starts_at': _iso(DateTime(now.year, now.month, now.day + 9, 18, 0)),
          'ends_at': _iso(DateTime(now.year, now.month, now.day + 9, 20, 30)),
          'event_type': 'trening',
          'rsvps': [],
          'going_count': 4,
          'maybe_count': 1,
          'my_status': null,
        },
      ];
    }

    // Chat — groups
    if (path == '/groups') {
      return [
        {
          'id': 1,
          'name': 'MFC Vysočina — všichni',
          'description': 'Hlavní kanál týmu',
          'member_count': 12,
          'last_message_at': _iso(DateTime.now().subtract(const Duration(minutes: 7))),
          'last_message_preview': 'Jakub: Kdo přinese gáza pásky?',
          'unread_count': 3,
        },
        {
          'id': 2,
          'name': 'Sestava A — boj',
          'description': 'Hlavní bojová sestava',
          'member_count': 5,
          'last_message_at': _iso(DateTime.now().subtract(const Duration(hours: 4))),
          'last_message_preview': 'Tomáš: Trénink prošel pičovsky',
          'unread_count': 0,
        },
        {
          'id': 3,
          'name': 'Zbrojíři + servis',
          'description': null,
          'member_count': 4,
          'last_message_at': _iso(DateTime.now().subtract(const Duration(days: 2))),
          'last_message_preview': 'Petra: Nové rukavice došly',
          'unread_count': 0,
        },
      ];
    }

    // Messages in a group
    final msgMatch = RegExp(r'^/groups/(\d+)/messages').firstMatch(path);
    if (msgMatch != null) {
      final gid = int.parse(msgMatch.group(1)!);
      final base = DateTime.now();
      return [
        {'id': 101, 'group_id': gid, 'author': _users[1], 'content': 'Sraz v 7:00 jak jsem psal v aktualitkách.', 'image_url': null, 'created_at': _iso(base.subtract(const Duration(minutes: 28)))},
        {'id': 102, 'group_id': gid, 'author': _users[2], 'content': 'Beru si svojí dvanáctku, vejdou se mi 4 lidi.', 'image_url': null, 'created_at': _iso(base.subtract(const Duration(minutes: 25)))},
        {'id': 103, 'group_id': gid, 'author': _users[3], 'content': 'Já beru škodovku, taky 4 lidi.', 'image_url': null, 'created_at': _iso(base.subtract(const Duration(minutes: 20)))},
        {'id': 104, 'group_id': gid, 'author': _users[4], 'content': 'Super, takže máme 8 míst v autě. Stačí.', 'image_url': null, 'created_at': _iso(base.subtract(const Duration(minutes: 18)))},
        {'id': 105, 'group_id': gid, 'author': _users[1], 'content': 'Kdo přinese gáza pásky?', 'image_url': null, 'created_at': _iso(base.subtract(const Duration(minutes: 7)))},
      ];
    }

    // Admin — list users (s podporou ?online_only=true)
    if (path == '/users' || path == '/admin/users') {
      final onlineOnly = query?['online_only'] == 'true';
      if (onlineOnly) {
        // Online = lastSeen < 5 min — vraci jen ty
        return _users.where((u) {
          final ls = u['last_seen'] as String?;
          if (ls == null) return false;
          final dt = DateTime.parse(ls);
          return DateTime.now().toUtc().difference(dt.toUtc()).inMinutes < 5;
        }).toList();
      }
      return _users;
    }

    // Admin — celkové statistiky
    if (path == '/admin/stats') {
      return {
        'total_users': _users.length,
        'online_users': _users.where((u) {
          final ls = u['last_seen'] as String?;
          if (ls == null) return false;
          return DateTime.now().toUtc().difference(DateTime.parse(ls).toUtc()).inMinutes < 5;
        }).length,
        'active_users_7d': _users.length,
        'total_posts': 4,
        'total_events': 4,
        'total_messages': 5,
      };
    }

    // Admin — eventy s rsvp_count (zjednodušená struktura)
    if (path == '/admin/events') {
      final all = get('/events') as List;
      return all.map((e) => {
        ...e as Map<String, dynamic>,
        'rsvp_count': (e['going_count'] as int) + (e['maybe_count'] as int),
      }).toList();
    }

    // Admin — skupiny s message_count + is_default
    if (path == '/admin/groups') {
      return [
        {
          'id': 1,
          'name': 'MFC Vysočina — všichni',
          'description': 'Hlavní kanál týmu',
          'member_count': 12,
          'message_count': 247,
          'is_default': true,
        },
        {
          'id': 2,
          'name': 'Sestava A — boj',
          'description': 'Hlavní bojová sestava',
          'member_count': 5,
          'message_count': 89,
          'is_default': false,
        },
        {
          'id': 3,
          'name': 'Zbrojíři + servis',
          'description': null,
          'member_count': 4,
          'message_count': 34,
          'is_default': false,
        },
      ];
    }

    // Tactics
    if (path == '/tactics') {
      return [
        {
          'id': 1,
          'title': 'Štít a meč — pohyb v sestavě',
          'description': 'Základní pohybové vzory ve čtyřčlenné sestavě, dynamické přesouvání těžiště.',
          'video_url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          'thumbnail_url': null,
          'category': '5v5',
          'sort_order': 1,
          'created_at': _iso(DateTime.now().subtract(const Duration(days: 5))),
        },
        {
          'id': 2,
          'title': 'Duel — odkrývání obrany protivníka',
          'description': 'Falešný útok, čtení reakce, rychlý finální zásah.',
          'video_url': 'https://www.youtube.com/watch?v=oHg5SJYRHA0',
          'thumbnail_url': null,
          'category': 'duely',
          'sort_order': 1,
          'created_at': _iso(DateTime.now().subtract(const Duration(days: 12))),
        },
        {
          'id': 3,
          'title': 'Obrana proti dvěma protivníkům',
          'description': 'Jak se otáčet, využít prostor a získat čas pro spolubojovníky.',
          'video_url': 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
          'thumbnail_url': null,
          'category': 'obrana',
          'sort_order': 2,
          'created_at': _iso(DateTime.now().subtract(const Duration(days: 30))),
        },
      ];
    }

    // Rules
    if (path == '/rules') {
      return [
        {
          'id': 1,
          'title': '5v5 — základní pravidla zápasu',
          'content':
              '## Cíl zápasu\n\nVyřadit všechny protivníky tím, že je dostanete na zem (3. bod kontaktu).\n\n## Délka\n\n- Maximálně **5 minut** za zápas\n- Při remíze pokračuje **náhlá smrt**\n\n## Zakázané techniky\n\n- údery do týlu nebo zezadu na hlavu\n- kopy do vnitřku stehen\n- záměrné páčení loktů či kolen',
          'category': '5v5',
          'document_url': null,
          'sort_order': 1,
          'updated_at': _iso(DateTime.now().subtract(const Duration(days: 7))),
          'created_at': _iso(DateTime.now().subtract(const Duration(days: 60))),
        },
        {
          'id': 2,
          'title': 'Vybavení — povinná zbroj',
          'content':
              '## Hlava\n\n- helma plně chránící hlavu i krk\n- vnitřní polstrování min. 1 cm\n\n## Tělo\n\n- kyrys nebo brigantina kryjící hrudník + záda\n- chrániče loktů a kolen\n\n## Ruce\n\n- ocelové rukavice (mitons / hourglass)\n\n> **Bez kompletní zbroje není povolen vstup do bojové zóny.**',
          'category': 'vybavení',
          'document_url': null,
          'sort_order': 1,
          'updated_at': _iso(DateTime.now().subtract(const Duration(days: 14))),
          'created_at': _iso(DateTime.now().subtract(const Duration(days: 90))),
        },
        {
          'id': 3,
          'title': 'Duely — bodový systém',
          'content':
              '## Body za zásah\n\n- **1 bod** — čistý zásah na ruku/nohu\n- **2 body** — zásah na trup\n- **3 body** — zásah na hlavu\n\n## Limit\n\nVítězí ten, kdo dosáhne **15 bodů**, nebo má víc bodů po 3 minutách.',
          'category': 'duely',
          'document_url': null,
          'sort_order': 1,
          'updated_at': _iso(DateTime.now().subtract(const Duration(days: 3))),
          'created_at': _iso(DateTime.now().subtract(const Duration(days: 30))),
        },
        {
          'id': 4,
          'title': 'Bezpečnost na tréninku',
          'content':
              '## Před tréninkem\n\n- zkontroluj zbroj — žádné prasklé řemínky, uvolněné nýty\n- zahřej si zápěstí, ramena, krk\n\n## Při tréninku\n\n- vždy hlas zranění hned\n- nepokračuj přes bolest\n- v páru — domluvte se na intenzitě',
          'category': 'bezpečnost',
          'document_url': null,
          'sort_order': 1,
          'updated_at': _iso(DateTime.now().subtract(const Duration(days: 1))),
          'created_at': _iso(DateTime.now().subtract(const Duration(days: 45))),
        },
      ];
    }

    return null; // not mocked → falls through to real network
  }

  /// Returns mock response for POST, or null to fall through.
  static dynamic post(String path, [Map<String, dynamic>? body]) {
    if (path == '/posts') {
      return {
        'id': DateTime.now().millisecondsSinceEpoch,
        'author': _users[0],
        'content': body?['content'] ?? '',
        'image_url': null,
        'pinned': false,
        'created_at': _iso(DateTime.now()),
      };
    }
    if (RegExp(r'^/posts/\d+/pin').hasMatch(path)) return {};
    if (RegExp(r'^/events/\d+/rsvp').hasMatch(path)) return {};
    if (RegExp(r'^/groups/\d+/messages').hasMatch(path)) {
      final gid = int.parse(RegExp(r'^/groups/(\d+)/messages').firstMatch(path)!.group(1)!);
      return {
        'id': DateTime.now().millisecondsSinceEpoch,
        'group_id': gid,
        'author': _users[0],
        'content': body?['content'] ?? '',
        'image_url': null,
        'created_at': _iso(DateTime.now()),
      };
    }
    return null;
  }
}
