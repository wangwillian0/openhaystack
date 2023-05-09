import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:openhaystack_mobile/accessory/accessory_model.dart';
import 'package:latlong2/latlong.dart';
import 'package:openhaystack_mobile/history/days_selection_slider.dart';
import 'package:openhaystack_mobile/history/location_popup.dart';

class AccessoryHistory extends StatefulWidget {
  Accessory accessory;

  /// Shows previous locations of a specific [accessory] on a map.
  /// The locations are connected by a chronological line.
  /// The number of days to go back can be adjusted with a slider.
  AccessoryHistory({
    Key? key,
    required this.accessory,
  }) : super(key: key);

  @override
  _AccessoryHistoryState createState() => _AccessoryHistoryState();
}

class _AccessoryHistoryState extends State<AccessoryHistory> {

  final MapController _mapController = MapController();

  bool showPopup = false;
  Pair<LatLng, DateTime>? popupEntry;

  double numberOfDays = 7;

  @override
  void initState() {
    super.initState();
  }

  void _onMapReady() {
    var historicLocations = widget.accessory.locationHistory
      .map((entry) => entry.a).toList();
    var bounds = LatLngBounds.fromPoints(historicLocations);
    _mapController.fitBounds(bounds);
  }

  @override
  Widget build(BuildContext context) {
    // Filter for the locations after the specified cutoff date (now - number of days)
    var now = DateTime.now();
    List<Pair<LatLng, DateTime>> locationHistory = widget.accessory.locationHistory.reversed
      .where(
        (element) => element.b.isAfter(
          now.subtract(Duration(days: numberOfDays.round())),
        ),
      ).toList();

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
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  onMapReady: _onMapReady,
                  center: LatLng(49.874739, 8.656280),
                  zoom: 13.0,
                  maxZoom: 18.0,
                  interactiveFlags:
                    InteractiveFlag.pinchZoom | InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom | InteractiveFlag.flingAnimation |
                    InteractiveFlag.pinchMove,
                  onTap: (_, __) {
                    setState(() {
                      showPopup = false;
                      popupEntry = null;
                    });
                  },
                ),
                nonRotatedChildren: const [
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text('© OpenStreetMap contributors', style: TextStyle(color: Colors.grey)),
                  )
                ],
                children: [
                  TileLayer(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    tileBuilder: (context, child, tile) {
                      var isDark = (Theme.of(context).brightness == Brightness.dark);
                      return isDark ? ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          -1, 0, 0, 0, 255,
                          0, -1, 0, 0, 255,
                          0, 0, -1, 0, 255,
                          0, 0, 0, 1, 0,
                        ]),
                        child: child,
                      ) : child;
                    },
                    urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                    subdomains: ['a', 'b', 'c'],
                  ),
                  // The markers for the historic locaitons
                  MarkerLayer(
                    markers: locationHistory.map((entry) => Marker(
                      point: entry.a,
                      builder: (ctx) => GestureDetector(
                        onTap: () {
                          setState(() {
                            showPopup = true;
                            popupEntry = entry;
                          });
                        },
                        child: Icon(
                          Icons.circle,
                          size: 15,
                          color: entry == popupEntry
                            ? Colors.green
                            : Color.lerp(Colors.red, Colors.blue, now.difference(entry.b).inSeconds / (numberOfDays * 24 * 60 * 60))
                        ),
                      ),
                    )).toList(),
                  ),
                  // Displays the tooltip if active
                  MarkerLayer(
                    markers: [
                      if (showPopup) LocationPopup(
                        location: popupEntry!.a,
                        time: popupEntry!.b,
                      ),
                    ],
                  ),
                ],
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
