// ignore_for_file: deprecated_member_use, avoid_multiple_declarations_per_line, avoid_catches_without_on_clauses

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

//=================================================//
final drawPolygonEnabledProvider = StateProvider<bool>((ref) => false);

final clearDrawingProvider = StateProvider<bool>((ref) => false);

final polygonSetProvider = StateProvider<Set<Polygon>>((ref) => {});

final getUserLocationProvider = StateProvider<LatLng>((ref) => const LatLng(0, 0));
//=================================================//

///
class HomeScreen extends StatefulHookConsumerWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

///
class HomeScreenState extends ConsumerState<HomeScreen> {
  static final Completer<GoogleMapController> _controller = Completer();

  bool _loading = true;

  int? _lastXCoordinate;

  int? _lastYCoordinate;

  Set<Polygon> get _polygonSet => ref.watch(polygonSetProvider);

  final Set<Polyline> _polylineSet = HashSet<Polyline>();

  final List<LatLng> _latLngList = [];

  ///
  @override
  void initState() {
    super.initState();

    _loading = true;

    _determinePosition();
  }

  ///
  @override
  Widget build(BuildContext context) {
    final drawPolygonEnabled = ref.watch(drawPolygonEnabledProvider);
    final currentPosition = ref.watch(getUserLocationProvider);
    return Scaffold(
      //

      body: _loading
          ? const CircularProgressIndicator()
          : GestureDetector(
              onPanUpdate: drawPolygonEnabled ? _onPanUpdate : null,
              onPanEnd: drawPolygonEnabled ? _onPanEnd : null,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: currentPosition,
                  zoom: 14.4746,
                ),
                polygons: _polygonSet,
                polylines: _polylineSet,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                onMapCreated: _controller.complete,
              ),
            ),

      //

      floatingActionButton: FloatingActionButton(
        onPressed: _toggleDrawing,
        backgroundColor: Theme.of(context).colorScheme.background,
        child: Icon(drawPolygonEnabled ? Icons.cancel : Icons.edit),
      ),

      //
    );
  }

  ///
  Future<void> _onPanUpdate(DragUpdateDetails details) async {
    if (ref.watch(clearDrawingProvider.state).state) {
      ref.read(clearDrawingProvider.state).state = false;

      _clearPolygons();
    }

    double? x, y;

    if (Platform.isAndroid) {
      x = details.localPosition.dx * 3;

      y = details.localPosition.dy * 3;
    } else if (Platform.isIOS) {
      x = details.localPosition.dx;

      y = details.localPosition.dy;
    }

    if (x != null && y != null) {
      final xCoordinate = x.round();
      final yCoordinate = y.round();

      if (_lastXCoordinate != null && _lastYCoordinate != null) {
        final distance = math.sqrt(
          math.pow(xCoordinate - _lastXCoordinate!, 2) + math.pow(yCoordinate - _lastYCoordinate!, 2),
        );

        if (distance > 80.0) {
          return;
        }
      }

      _lastXCoordinate = xCoordinate;

      _lastYCoordinate = yCoordinate;

      final screenCoordinate = ScreenCoordinate(x: xCoordinate, y: yCoordinate);

      final controller = await _controller.future;

      final latLng = await controller.getLatLng(screenCoordinate);

      try {
        _latLngList.add(latLng);

        _polylineSet
          ..removeWhere((polyline) => polyline.polylineId.value == 'user_polyline')
          ..add(
            Polyline(
              polylineId: const PolylineId('user_polyline'),
              points: _latLngList,
              width: 2,
              color: Colors.blue,
            ),
          );
      } catch (e) {
        if (kDebugMode) {
          print(' error painting $e');
        }
      }

      ref.read(polygonSetProvider.state).state = {..._polygonSet};
    }
  }

  ///
  Future<void> _onPanEnd(DragEndDetails details) async {
    _lastXCoordinate = null;

    _lastYCoordinate = null;

    _polygonSet
      ..removeWhere((polygon) => polygon.polygonId.value == 'user_polygon')
      ..add(
        Polygon(
          polygonId: const PolygonId('user_polygon'),
          points: _latLngList,
          strokeWidth: 2,
          strokeColor: Colors.blue,
          fillColor: Colors.blue.withOpacity(0.4),
        ),
      );

    /*
    print(_polygonSet.first.points.length);
    print(_polygonSet.first.points);

I/flutter ( 1134): 115
I/flutter ( 1134): [
LatLng(35.71194582489052, 139.94988664984703),
LatLng(35.71192921877202, 139.95003081858158),
LatLng(35.71191234041853, 139.95011296123266),
LatLng(35.711879128164135, 139.95023667812347),
LatLng(35.711879128164135, 139.95031882077456),
LatLng(35.71184564366413, 139.9504012987018),
LatLng(35.71181215915008, 139.95048377662897),
LatLng(35.71177867462193, 139.95058670639992),
LatLng(35.7117620684686, 139.950668849051),
LatLng(35.71172858391942, 139.9507513269782), LatLng(35.71171170552345, 139.95083380490541), LatLng(35.711678493185424, 139.9509159475565), LatLng(35.711661614778855, 139.95099842548373), LatLng(35.71162813018745, 139.95106011629105), LatLng(35.71159491781461, 139.9511218070984), LatLng(35.71156143319522, 139.951163046062), LatLng(35.71154455476384, 139.95122507214546), LatLng(35.7114944639142, 139.9512867629528), LatLng(35.71147785770167, 139.95130721479654), LatLng(35.71141088835042, 139.95138969272375), LatLng(35.71137740365368, 139.95143093168736), LatLng(35.71134391894289, 139.951471835374
    */

    ref.read(drawPolygonEnabledProvider.state).update((state) => !state);
  }

  ///
  void _toggleDrawing() {
    _clearPolygons();

    ref.read(drawPolygonEnabledProvider.state).update((state) => !state);
  }

  ///
  void _clearPolygons() {
    _latLngList.clear();

    _polylineSet.clear();

    _polygonSet.clear();
  }

  ///
  Future<Position> _determinePosition() async {
    bool serviceEnabled;

    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('位置情報サービスが無効です。');
    }

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        return Future.error('位置情報を取得する権限がありません。');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('位置情報サービスの権限が永久に拒否されています。権限を要求することができません。');
    }

    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    _loading = false;

    ref.read(getUserLocationProvider.state).state = LatLng(position.latitude, position.longitude);

    return position;
  }
}
