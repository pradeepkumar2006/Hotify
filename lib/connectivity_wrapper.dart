import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'no_internet_screen.dart';

class ConnectivityWrapper extends StatelessWidget {
  final Widget child;

  const ConnectivityWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final results = snapshot.data!;
          // If the only result is 'none', there is no connection.
          if (results.contains(ConnectivityResult.none) && results.length == 1) {
            return const NoInternetScreen();
          }
        }
        
        // Default to showing the normal app if connection is present or unknown (loading).
        return child;
      },
    );
  }
}
