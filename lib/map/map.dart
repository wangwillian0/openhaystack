import 'package:flutter/material.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:provider/provider.dart';
import 'package:openhaystack_mobile/accessory/accessory_icon.dart';
import 'package:openhaystack_mobile/accessory/accessory_model.dart';
import 'package:openhaystack_mobile/accessory/accessory_registry.dart';
import 'package:openhaystack_mobile/location/location_model.dart';

class AccessoryMap extends StatefulWidget {
  final Function(MapboxMapController)? onMapCreatedCallback;

  /// Displays a map with all accessories at their latest position.
  const AccessoryMap({
    Key? key,
    this.onMapCreatedCallback,
  }): super(key: key);

  @override
  _AccessoryMapState createState() => _AccessoryMapState();
}

class _AccessoryMapState extends State<AccessoryMap> {
  MapboxMapController? _mapController;
  void Function()? cancelLocationUpdates;
  void Function()? cancelAccessoryUpdates;
  bool accessoryInitialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();

    cancelLocationUpdates?.call();
    cancelAccessoryUpdates?.call();
  }

  void fitToContent(List<Accessory> accessories, LatLng? hereLocation) async {
    // Delay to prevent race conditions
    await Future.delayed(const Duration(milliseconds: 500));

    List<LatLng> points = [
      ...accessories
          .where((accessory) => accessory.lastLocation != null)
          .map((accessory) => accessory.lastLocation!),
      if (hereLocation != null) hereLocation,
    ].toList();
    
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            points.map((point) => point.latitude).reduce((value, element) => value < element ? value : element)   - 0.003,
            points.map((point) => point.longitude).reduce((value, element) => value < element ? value : element)  - 0.003,
          ),
          northeast: LatLng(
            points.map((point) => point.latitude).reduce((value, element) => value > element ? value : element)   + 0.003,
            points.map((point) => point.longitude).reduce((value, element) => value > element ? value : element)  + 0.003,
          ),
        ),
        left: 25, top: 25, right: 25, bottom: 25,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AccessoryRegistry, LocationModel>(
      builder: (BuildContext context, AccessoryRegistry accessoryRegistry, LocationModel locationModel, Widget? child) {
        // Zoom map to fit all accessories on first accessory update
        var accessories = accessoryRegistry.accessories;
        if (!accessoryInitialized && accessoryRegistry.initialLoadFinished) {
          fitToContent(accessories, locationModel.here);

          accessoryInitialized = true;
        }
        
        onMapCreated(MapboxMapController controller) {
          _mapController = controller;
          widget.onMapCreatedCallback!(controller);
          if (!accessoryInitialized) {
            fitToContent(accessoryRegistry.accessories, locationModel.here);
          }
        }
        
        onStyleLoaded() {
          // void  locationModelListener () {
          //   locationModel.removeListener(locationModelListener);
          //   _mapController!.addCircle(
          //     CircleOptions(
          //       geometry: locationModel.here!,
          //       circleRadius: 8,
          //       circleColor: "#007AFF",
          //       circleStrokeColor: "#FFFFFF",
          //       circleStrokeWidth: 2,
          //     ),
          //   );
          // }
          // locationModel.addListener(locationModelListener);

          _mapController!.addCircles(
            accessories
              .where((accessory) => accessory.lastLocation != null)
              .map((accessory) => CircleOptions(
                geometry: accessory.lastLocation!,
                circleRadius: 12,
                circleColor: "#FFFFFF",
                circleStrokeColor: accessory.color.toHexStringRGB(),
                circleStrokeWidth: 3,
              ))
              .toList(),
          );
          _mapController!.addSymbols(
            accessories
              .where((accessory) => accessory.lastLocation != null)
              .map((accessory) => SymbolOptions(
                geometry: accessory.lastLocation!,
                // iconImage: accessory.icon.toString(),
                iconImage: "rocket-15",
                iconSize: 1.2,
                textField: accessory.name,
                textColor: "#000000",
                textOffset: const Offset(0, 1.5),
                iconColor: accessory.color.toHexStringRGB(),
              ))
              .toList(),
          );
          
        }

        return MapboxMap(
          accessToken: const String.fromEnvironment("MAP_SDK_PUBLIC_KEY"),
          onMapCreated: onMapCreated,
          onStyleLoadedCallback: onStyleLoaded,
          initialCameraPosition: CameraPosition(
            target: locationModel.here ?? const LatLng(-23.559389, -46.731839),
            zoom: 13.0,
          ),
          // styleString: Theme.of(context).brightness == Brightness.dark ? MapboxStyles.DARK : MapboxStyles.LIGHT,
          annotationOrder: const [
            AnnotationType.circle,
            AnnotationType.symbol
          ],
        );
      }
    );
  }
}
