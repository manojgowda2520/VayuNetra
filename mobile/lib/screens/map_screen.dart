import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../config/theme.dart';
import '../config/constants.dart';
import '../providers/location_provider.dart';
import '../providers/language_provider.dart';
import '../providers/report_provider.dart';
import '../models/report.dart';
import '../widgets/severity_badge.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _defaultCenter = LatLng(12.9716, 77.5946);

  String _filter = 'All';
  final _filters = ['All', 'Critical', 'High', 'Moderate', 'Low'];
  GoogleMapController? _mapController;

  double _markerHue(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return BitmapDescriptor.hueRed;
      case 'HIGH':
        return BitmapDescriptor.hueOrange;
      case 'MODERATE':
        return BitmapDescriptor.hueYellow;
      case 'LOW':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueAzure;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().fetchReports();
      _loadCurrentLocation();
    });
  }

  Future<void> _loadCurrentLocation() async {
    final loc = context.read<LocationProvider>();
    await loc.getCurrentLocation();
    if (!mounted || _mapController == null || loc.lat == null || loc.lng == null) {
      return;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(loc.lat!, loc.lng!), 14.5),
    );
  }

  Future<void> _focusCurrentLocation() async {
    await _loadCurrentLocation();
    final loc = context.read<LocationProvider>();
    if (!mounted || (loc.lat != null && loc.lng != null)) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Current location is not available right now.')),
    );
  }

  List<Report> _reportsForFilter(List<Report> reports, String filter) {
    if (filter == 'All') {
      return reports;
    }
    return reports.where((r) => r.analysis?.severity.toUpperCase() == filter.toUpperCase()).toList();
  }

  Future<void> _zoomToReports(List<Report> reports) async {
    final controller = _mapController;
    if (controller == null || reports.isEmpty) {
      return;
    }

    if (reports.length == 1) {
      final report = reports.first;
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(report.latitude, report.longitude), 15),
      );
      return;
    }

    double minLat = reports.first.latitude;
    double maxLat = reports.first.latitude;
    double minLng = reports.first.longitude;
    double maxLng = reports.first.longitude;

    for (final report in reports.skip(1)) {
      if (report.latitude < minLat) minLat = report.latitude;
      if (report.latitude > maxLat) maxLat = report.latitude;
      if (report.longitude < minLng) minLng = report.longitude;
      if (report.longitude > maxLng) maxLng = report.longitude;
    }

    if (minLat == maxLat) {
      minLat -= 0.005;
      maxLat += 0.005;
    }
    if (minLng == maxLng) {
      minLng -= 0.005;
      maxLng += 0.005;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        56,
      ),
    );
  }

  void _showDetails(Report report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VNColors.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SingleChildScrollView(child: Column(children: [
        if (report.photoUrl != null)
          ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: CachedNetworkImage(imageUrl: report.photoUrl!, height: 200, width: double.infinity, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(height: 200, color: VNColors.bgCard2,
                child: const Icon(Icons.image, color: VNColors.muted, size: 60)))),
        Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(report.area, style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 20, fontWeight: FontWeight.bold, color: VNColors.text))),
            if (report.analysis != null) SeverityBadge(severity: report.analysis!.severity),
          ]),
          if (report.analysis != null) ...[
            const SizedBox(height: 4),
            Text(report.analysis!.pollutionType, style: const TextStyle(color: VNColors.cyan, fontFamily: 'DMSans', fontSize: 14)),
            const SizedBox(height: 8),
            Text(report.analysis!.description, style: const TextStyle(color: VNColors.muted, fontFamily: 'DMSans', fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          Text(timeago.format(report.createdAt), style: const TextStyle(color: VNColors.muted, fontSize: 12, fontFamily: 'DMSans')),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: VNColors.cyan, foregroundColor: Colors.black),
            onPressed: () { Navigator.pop(context); Navigator.pushNamed(context, AppConstants.reportDetail, arguments: report); },
            child: Text('${context.t('viewFullReport')} →', style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.bold)),
          )),
        ])),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VNColors.bg,
      appBar: AppBar(
        backgroundColor: VNColors.bg,
        title: Text(context.t('livePollutionMap'), style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 20, color: VNColors.text)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: VNColors.text), onPressed: () => Navigator.pop(context)),
      ),
      body: Consumer2<ReportProvider, LocationProvider>(builder: (_, reps, loc, __) {
        final reports = _reportsForFilter(reps.reports, _filter);
        final markers = reports.map((r) {
          final severity = r.analysis?.severity ?? 'UNKNOWN';
          return Marker(
            markerId: MarkerId('report-${r.id}'),
            position: LatLng(r.latitude, r.longitude),
            infoWindow: InfoWindow(
              title: r.area,
              snippet: r.analysis?.pollutionType ?? r.status,
              onTap: () => _showDetails(r),
            ),
            onTap: () => _showDetails(r),
            icon: BitmapDescriptor.defaultMarkerWithHue(_markerHue(severity)),
          );
        }).toSet();

        if (loc.lat != null && loc.lng != null) {
          markers.add(
            Marker(
              markerId: const MarkerId('current-location'),
              position: LatLng(loc.lat!, loc.lng!),
              infoWindow: InfoWindow(
                title: 'Your location',
                snippet: loc.areaName.isNotEmpty ? loc.areaName : 'Current position',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            ),
          );
        }

        return Stack(children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultCenter,
              zoom: 11.5,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              if (loc.lat != null && loc.lng != null) {
                controller.animateCamera(
                  CameraUpdate.newLatLngZoom(LatLng(loc.lat!, loc.lng!), 14.5),
                );
              }
            },
            myLocationEnabled: loc.lat != null && loc.lng != null,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: markers,
          ),

          // Filter chips
          Positioned(top: 12, left: 12, right: 12,
            child: SingleChildScrollView(scrollDirection: Axis.horizontal,
              child: Row(children: _filters.map((f) {
                final active = _filter == f;
                return Padding(padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(onTap: () {
                    final filteredReports = _reportsForFilter(reps.reports, f);
                    setState(() => _filter = f);
                    _zoomToReports(filteredReports);
                  },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: active ? VNColors.cyan : VNColors.bgCard.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? VNColors.cyan : VNColors.border),
                      ),
                      child: Text(f, style: TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.bold, fontSize: 13,
                        color: active ? Colors.black : VNColors.text)),
                    )));
              }).toList()),
            )),

          // Count badge
          Positioned(bottom: 80, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: VNColors.bgCard.withOpacity(0.9), borderRadius: BorderRadius.circular(20), border: Border.all(color: VNColors.border)),
              child: Text('${reports.length} ${context.t('reports').toLowerCase()}', style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 13, color: VNColors.cyan)),
            )),

          Positioned(
            right: 12,
            bottom: 144,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _focusCurrentLocation,
                borderRadius: BorderRadius.circular(18),
                child: Ink(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: VNColors.bgCard.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: VNColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.my_location, color: VNColors.cyan, size: 22),
                ),
              ),
            ),
          ),
        ]);
      }),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppConstants.report),
        backgroundColor: VNColors.saffron,
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        label: Text(context.t('report'), style: const TextStyle(fontFamily: 'Rajdhani', fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}
