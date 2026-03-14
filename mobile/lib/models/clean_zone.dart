class CleanZone {
  final String name;
  final int aqi;
  final String status;
  final double latitude;
  final double longitude;
  final List<String> activities;

  CleanZone({
    required this.name,
    required this.aqi,
    required this.status,
    required this.latitude,
    required this.longitude,
    required this.activities,
  });

  factory CleanZone.fromJson(Map<String, dynamic> j) => CleanZone(
    name:       j['name'] ?? '',
    aqi:        j['aqi'] ?? 0,
    status:     j['status'] ?? 'Good',
    latitude:   (j['latitude'] ?? 0.0).toDouble(),
    longitude:  (j['longitude'] ?? 0.0).toDouble(),
    activities: List<String>.from(j['activities'] ?? []),
  );

  static List<CleanZone> get fallback => [
    CleanZone(name: 'Cubbon Park',       aqi: 34, status: 'Excellent', latitude: 12.9763, longitude: 77.5929, activities: ['Jogging','Yoga','Kids','Elderly']),
    CleanZone(name: 'Lalbagh Garden',    aqi: 28, status: 'Excellent', latitude: 12.9507, longitude: 77.5848, activities: ['Nature walk','Yoga','Photography']),
    CleanZone(name: 'Nandi Hills',       aqi: 12, status: 'Pristine',  latitude: 13.3702, longitude: 77.6835, activities: ['Cycling','Sunrise','Camping']),
    CleanZone(name: 'Hesaraghatta Lake', aqi: 18, status: 'Excellent', latitude: 13.1378, longitude: 77.4617, activities: ['Birdwatching','Walking']),
    CleanZone(name: 'Bannerghatta Park', aqi: 45, status: 'Good',      latitude: 12.7993, longitude: 77.5765, activities: ['Wildlife','Trekking']),
    CleanZone(name: 'Turahalli Forest',  aqi: 38, status: 'Good',      latitude: 12.8871, longitude: 77.5237, activities: ['Running','MTB']),
  ];
}
