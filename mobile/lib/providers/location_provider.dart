import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationProvider extends ChangeNotifier {
  double? _lat;
  double? _lng;
  String _areaName = '';
  bool _loading = false;

  double? get lat => _lat;
  double? get lng => _lng;
  String get areaName => _areaName;
  bool get loading => _loading;

  Future<void> getCurrentLocation() async {
    _loading = true; notifyListeners();
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) {
        _areaName = 'Permission denied'; _loading = false; notifyListeners(); return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _lat = pos.latitude; _lng = pos.longitude;
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty) {
        final p = marks.first;
        _areaName = p.subLocality?.isNotEmpty == true
            ? '${p.subLocality}, ${p.locality}' : p.locality ?? 'Bengaluru';
      }
    } catch (_) { _areaName = 'Location error'; }
    _loading = false; notifyListeners();
  }
}
