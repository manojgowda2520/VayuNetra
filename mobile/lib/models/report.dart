class AnalysisResult {
  final String severity;
  final String pollutionType;
  final String healthRisk;
  final String description;
  final double confidence;
  final List<String> recommendations;
  final String complaintLetter;
  final String estimatedAqiImpact;
  final String estimatedAqiRange;

  AnalysisResult({
    required this.severity,
    required this.pollutionType,
    required this.healthRisk,
    required this.description,
    required this.confidence,
    required this.recommendations,
    required this.complaintLetter,
    this.estimatedAqiImpact = 'Moderate',
    this.estimatedAqiRange = '51–100',
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> j) => AnalysisResult(
    severity:            j['severity'] ?? 'MODERATE',
    pollutionType:       j['pollution_type'] ?? 'Unknown',
    healthRisk:          j['health_risk'] ?? '',
    description:         j['description'] ?? '',
    confidence:          (j['confidence'] ?? 0.8).toDouble(),
    recommendations:    List<String>.from(j['recommendations'] ?? []),
    complaintLetter:     j['complaint_letter'] ?? '',
    estimatedAqiImpact:  j['estimated_aqi_impact'] ?? 'Moderate',
    estimatedAqiRange:   j['estimated_aqi_range'] ?? '51–100',
  );
}

class Report {
  final int id;
  final int? userId;
  final String area;
  final double latitude;
  final double longitude;
  final String? description;
  final String? photoUrl;
  final String status;
  final DateTime createdAt;
  final AnalysisResult? analysis;

  Report({
    required this.id,
    this.userId,
    required this.area,
    required this.latitude,
    required this.longitude,
    this.description,
    this.photoUrl,
    required this.status,
    required this.createdAt,
    this.analysis,
  });

  factory Report.fromJson(Map<String, dynamic> j) => Report(
    id:          j['id'] ?? j['report_id'] ?? 0,
    userId:      j['user_id'],
    area:        j['area'] ?? '',
    latitude:    (j['latitude'] ?? 0.0).toDouble(),
    longitude:   (j['longitude'] ?? 0.0).toDouble(),
    description: j['description'],
    photoUrl:    j['photo_url'],
    status:      j['status'] ?? 'analyzed',
    createdAt:   DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
    analysis:    j['analysis'] != null
                   ? AnalysisResult.fromJson(j['analysis'])
                   : null,
  );
}
