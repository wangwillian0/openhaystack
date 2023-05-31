import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_gl/mapbox_gl.dart';
import 'package:provider/provider.dart';
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
  bool mapStyleLoaded = false;

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
    
    _mapController?.moveCamera(
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

  onMapCreated(MapboxMapController controller, UnmodifiableListView<Accessory> accessories, LocationModel locationModel) {
    _mapController = controller;
    widget.onMapCreatedCallback!(controller);
    if (!accessoryInitialized) {
      fitToContent(accessories, locationModel.here);
    }
  }

  /// Adds an asset image to the currently displayed style
  Future<void> addImageFromAsset(MapboxMapController controller, String name, String assetName) async {
    final ByteData bytes = await rootBundle.load(assetName);
    final Uint8List list = bytes.buffer.asUint8List();
    return controller.addImage(name, list);
  }

  updateMarkers(MapboxMapController controller, UnmodifiableListView<Accessory> accessories) async {
    mapStyleLoaded = true;
    controller.removeCircles(controller.circles);
    controller.removeSymbols(controller.symbols);

    Set<String> iconStrings = accessories.map((accessory) => accessory.iconString).toSet();
    for (String iconString in iconStrings) {
      // to convert from svg to RGBA png use `convert -background "rgba(0,0,0,0)" $f png32:${f%.*}.png`
      await addImageFromAsset(controller, iconString, "assets/accessory_icons/$iconString.png");
    }

    controller.addCircles(
      accessories
        .where((accessory) => accessory.lastLocation != null)
        .map((accessory) => CircleOptions(
          geometry: accessory.lastLocation!,
          circleRadius: 12,
          circleColor: "#FFFFFF",
          circleStrokeColor: accessory.color.toHexStringRGB(),
          circleStrokeWidth: 4,
        ))
        .toList(),
    );
    controller.addSymbols(
      accessories
        .where((accessory) => accessory.lastLocation != null)
        .map((accessory) => SymbolOptions(
          geometry: accessory.lastLocation!,
          iconImage: accessory.iconString,
          iconSize: 0.425 * MediaQuery.of(context).devicePixelRatio,
          textField: accessory.name,
          textColor: "#000000",
          textOffset: const Offset(0, 1.5),
        ))
        .toList(),
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
        
        if (mapStyleLoaded) {
          updateMarkers(_mapController!, accessories);
        }

        return MapboxMap(
	        myLocationEnabled: true,
          accessToken: const String.fromEnvironment("MAP_SDK_PUBLIC_KEY"),
          onMapCreated: (controller) => onMapCreated(controller, accessories, locationModel),
          onStyleLoadedCallback: () => updateMarkers(_mapController!, accessories),
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
