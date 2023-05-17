import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:openhaystack_mobile/dashboard/dashboard_desktop.dart';
import 'package:openhaystack_mobile/dashboard/dashboard_mobile.dart';
import 'package:openhaystack_mobile/accessory/accessory_registry.dart';
import 'package:openhaystack_mobile/item_management/item_file_import.dart';
import 'package:openhaystack_mobile/location/location_model.dart';
import 'package:openhaystack_mobile/preferences/user_preferences_model.dart';
import 'package:openhaystack_mobile/splashscreen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => AccessoryRegistry()),
        ChangeNotifierProvider(create: (ctx) => UserPreferences()),
        ChangeNotifierProvider(create: (ctx) => LocationModel()),
      ],
      child: MaterialApp(
        title: 'OpenHaystack',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        darkTheme: ThemeData.dark(),
        home:  const AppLayout(),
      ),
    );
  }
}

class AppLayout extends StatefulWidget {
  const AppLayout({Key? key}) : super(key: key);

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  StreamSubscription? _intentDataStreamSubscription;

  @override
  initState() {
    super.initState();

    var accessoryRegistry = Provider.of<AccessoryRegistry>(context, listen: false);
    accessoryRegistry.loadAccessories();
  }

  @override
  void dispose() {
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    // Precache logo for faster load times (e.g. on the splash screen)
    precacheImage(const AssetImage('assets/OpenHaystackIcon.png'), context);
    super.didChangeDependencies();
  }


  @override
  Widget build(BuildContext context) {
    bool isInitialized = context.watch<UserPreferences>().initialized;
    bool isLoading = context.watch<AccessoryRegistry>().loading;
    if (!isInitialized || isLoading) {
      return const Splashscreen();
    }

    Size screenSize = MediaQuery.of(context).size;
    Orientation orientation = MediaQuery.of(context).orientation;

    // TODO: More advanced media query handling
    if (screenSize.width < 800) {
      return const DashboardMobile();
    } else {
      return const DashboardMobile();	    
    }
  }
}
