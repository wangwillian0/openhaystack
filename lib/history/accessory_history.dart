import 'package:flutter/material.dart';
import 'package:openhaystack_mobile/accessory/accessory_model.dart';
import 'package:openhaystack_mobile/history/days_selection_slider.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

class AccessoryHistory extends StatefulWidget {
  final Accessory accessory;

  /// Shows previous locations of a specific [accessory] on a map.
  /// The locations are connected by a chronological line.
  /// The number of days to go back can be adjusted with a slider.
  const AccessoryHistory({
    Key? key,
    required this.accessory,
  }) : super(key: key);

  @override
  _AccessoryHistoryState createState() => _AccessoryHistoryState();
}

class _AccessoryHistoryState extends State<AccessoryHistory> {
  MapboxMapController? _mapController;

  double numberOfDays = 7;

  @override
  void initState() {
    super.initState();
  }

  void _onMapCreated(MapboxMapController controller) {
    _mapController = controller;
  }

  void _updateMarkers() {
    _mapController?.removeCircles(_mapController?.circles ?? []);
    
    var now = DateTime.now();

    var options = widget.accessory.locationHistory
      .where ((entry) => entry.b.isAfter(now.subtract(Duration(days: numberOfDays.round()))))
      .map((entry) => CircleOptions(
        geometry: entry.a,
        circleRadius: 6,
        circleColor: Color.lerp(
          Colors.red, Colors.blue,
          now.difference(entry.b).inSeconds / (numberOfDays * 24 * 60 * 60)
        )!.toHexStringRGB(),
    )).toList();

    var data = widget.accessory.locationHistory
      .where ((entry) => entry.b.isAfter(now.subtract(Duration(days: numberOfDays.round()))))
      .map((entry) => {
        'time': entry.b,
    }).toList();
    
    _mapController?.addCircles(options, data);
  }

  void _onStyleLoaded() {    
    _mapController?.moveCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            widget.accessory.locationHistory.map((entry) => entry.a.latitude).reduce((value, element) => value < element ? value : element),
            widget.accessory.locationHistory.map((entry) => entry.a.longitude).reduce((value, element) => value < element ? value : element),
          ),
          northeast: LatLng(
            widget.accessory.locationHistory.map((entry) => entry.a.latitude).reduce((value, element) => value > element ? value : element),
            widget.accessory.locationHistory.map((entry) => entry.a.longitude).reduce((value, element) => value > element ? value : element),
          ),
        ),
        left: 25, top: 25, right: 25, bottom: 25,
      ),
    );
    
    _mapController!.onCircleTapped.add(_onCircleTapped);

    _updateMarkers();
  }

  void _onCircleTapped(Circle circle) {
    final originalCircleColor = circle.options.circleColor;
    _mapController!.updateCircle(circle, CircleOptions(circleColor: Colors.green.toHexStringRGB()));

    final snackBar = SnackBar(
        content: Text(
          '${circle.data!['time'].toLocal().toString().substring(0, 19)}\n'
          'Lat: ${circle.options.geometry!.latitude}\n'
          'Lng: ${circle.options.geometry!.longitude}',
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Theme.of(context).primaryColor);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(snackBar).closed.then((_) {
      _mapController!.updateCircle(circle, CircleOptions(circleColor: originalCircleColor));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.accessory.name),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Flexible(
              flex: 3,
              fit: FlexFit.tight,
              child: MapboxMap(
                accessToken: const String.fromEnvironment("MAP_SDK_PUBLIC_KEY"),
                onMapCreated: _onMapCreated,
                onStyleLoadedCallback: _onStyleLoaded,
                initialCameraPosition: const CameraPosition(
                  target: LatLng(-23.559389, -46.731839),
                  zoom: 13.0,
                ),
                styleString: Theme.of(context).brightness == Brightness.dark ? MapboxStyles.DARK : MapboxStyles.LIGHT,
              ),
            ),
            Flexible(
              flex: 1,
              fit: FlexFit.tight,
              child: DaysSelectionSlider(
                numberOfDays: numberOfDays,
                onChanged: (double newValue) {
                  setState(() {
                    numberOfDays = newValue;
                    _updateMarkers();
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
