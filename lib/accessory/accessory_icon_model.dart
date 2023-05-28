import 'package:flutter/material.dart';

class AccessoryIconModel {
  /// A list of all available icons
  static const List<String> icons = [
    "credit_card", "business_center", "work", "vpn_key",
    "place", "push_pin", "language", "school",
    "redeem", "directions_car", "pedal_bike", "directions_walk",
    "favorite", "pets", "bug_report", "visibility",
  ];

  /// A mapping from the cupertino icon names to the material icon names.
  /// 
  /// If the icons do not match, so a similar replacement is used.
  static const iconMapping = {
    'credit_card': Icons.credit_card,
    'business_center': Icons.business_center,
    'work': Icons.work,
    'vpn_key': Icons.vpn_key,
    'place': Icons.place,
    'push_pin': Icons.push_pin,
    'language': Icons.language,
    'school': Icons.school,
    'redeem': Icons.redeem,
    'directions_car': Icons.directions_car,
    'pedal_bike': Icons.pedal_bike,
    'directions_walk': Icons.directions_walk,
    'favorite': Icons.favorite,
    'pets': Icons.pets,
    'bug_report': Icons.bug_report,
    'visibility': Icons.visibility,
  };

  /// Looks up the equivalent material icon for the cupertino icon [iconName].
  static IconData? mapIcon(String iconName) {
    return iconMapping[iconName];
  }
}
