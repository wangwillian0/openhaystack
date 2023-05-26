import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geocode;
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:geolocator/geolocator.dart';

class LocationModel extends ChangeNotifier {
  LatLng? here;
  geocode.Placemark? herePlace;
  StreamSubscription<Position>? locationStream;
  bool initialLocationSet = false;

  /// Requests access to the device location from the user.
  /// 
  /// Initializes the location services and requests location
  /// access from the user if not granged.
  /// Returns if location access was granted.
  Future<bool> requestLocationAccess() async {
    // Enable location service
    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return false;
    }

    // Request location access from user if not permanently denied or already granted
    var permissionGranted = await Geolocator.checkPermission();
    if (permissionGranted == LocationPermission.denied) {
      permissionGranted = await Geolocator.requestPermission();
      if (permissionGranted == LocationPermission.denied) {
        debugPrint('Location access is denied.');
        return false;
      }
    }

    return true;
  }

  /// Requests location updates from the platform.
  /// 
  /// Listeners will be notified about locaiton changes.
  Future<void> requestLocationUpdates() async {
    var permissionGranted = await requestLocationAccess();
    if (permissionGranted) {

      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      );

      // Handle future location updates
      locationStream ??= Geolocator.getPositionStream(locationSettings: locationSettings).listen(_updateLocation);

      // Fetch the current location
      var locationData = await Geolocator.getCurrentPosition();
      _updateLocation(locationData);
    } else {
      initialLocationSet = true;
      if (locationStream != null) {
        locationStream?.cancel();
        locationStream = null;
      }
      _removeCurrentLocation();
      notifyListeners();
    }
  }

  /// Updates the current location if new location data is available.
  /// 
  /// Additionally updates the current address information to match
  /// the new location.
  void _updateLocation(Position? locationData) {
    if (locationData != null) {
      // debugPrint('Locaiton here: ${locationData.latitude!}, ${locationData.longitude!}');
      here = LatLng(locationData.latitude, locationData.longitude);
      initialLocationSet = true;
      getAddress(here!)
        .then((value) {
          herePlace = value;
          notifyListeners();
        });
    } else {
      debugPrint('Received invalid location data: $locationData');
    }
    notifyListeners();
  }

  /// Cancels the listening for location updates.
  void cancelLocationUpdates() {
    if (locationStream != null) {
      locationStream?.cancel();
      locationStream = null;
    }
    _removeCurrentLocation();
    notifyListeners();
  }

  /// Resets the currently stored location and address information
  void _removeCurrentLocation() {
    here = null;
    herePlace = null;
  }

  /// Returns the address for a given geolocation (latitude & longitude).
  /// 
  /// Only works on mobile platforms with their local APIs.
  static Future<geocode.Placemark?> getAddress(LatLng? location) async {
    if (location == null) {
      return null;
    }
    double lat = location.latitude;
    double lng = location.longitude;

    try {
      List<geocode.Placemark> placemarks = await geocode.placemarkFromCoordinates(lat, lng);
      return placemarks.first;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null; 
    }
  }

}
