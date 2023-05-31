import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openhaystack_mobile/accessory/accessory_list.dart';
import 'package:openhaystack_mobile/accessory/accessory_registry.dart';
import 'package:openhaystack_mobile/location/location_model.dart';
import 'package:openhaystack_mobile/map/map.dart';
import 'package:mapbox_gl/mapbox_gl.dart';

class AccessoryMapListVertical extends StatefulWidget {
  final AsyncCallback loadLocationUpdates;

  /// Displays a map view and the accessory list in a vertical alignment.
  const AccessoryMapListVertical({
    Key? key,
    required this.loadLocationUpdates,
  }) : super(key: key);

  @override
  State<AccessoryMapListVertical> createState() => _AccessoryMapListVerticalState();
}

class _AccessoryMapListVerticalState extends State<AccessoryMapListVertical> {
  MapboxMapController? _mapController;

  void _centerPoint(LatLng point) {
    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: point,
          zoom: 15.0,
        ),
      )
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer2<AccessoryRegistry, LocationModel>(
      builder: (BuildContext context, AccessoryRegistry accessoryRegistry, LocationModel locationModel, Widget? child) {
        return Column(
          children: [
            Flexible(
              fit: FlexFit.tight,
              child: AccessoryMap(
                onMapCreatedCallback: (controller) {
                  _mapController = controller;
                },
              ),
            ),
            Flexible(
              fit: FlexFit.tight,
              child: AccessoryList(
                loadLocationUpdates: widget.loadLocationUpdates,
                centerOnPoint: _centerPoint,
              ),
            ),
          ],
        );
      },
    );
  }
}
