class User {
  final int id;
  final String name;
  final String email;
  final int points;
  final String badgeLevel;
  final int reportCount;
  final DateTime createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.points,
    required this.badgeLevel,
    required this.reportCount,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
    id:          j['id'],
    name:        j['name'] ?? '',
    email:       j['email'] ?? '',
    points:      j['points'] ?? 0,
    badgeLevel:  j['badge_level'] ?? 'Bronze Guardian',
    reportCount: j['report_count'] ?? 0,
    createdAt:   DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
  );

  String get initials {
    final p = name.trim().split(' ');
    if (p.length >= 2) return '${p[0][0]}${p[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }
}
