import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../Services/LocationService.dart';

class MapLocationResult {
  final String address;
  final double latitude;
  final double longitude;

  const MapLocationResult({
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class MapLocationPickerScreen extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;

  const MapLocationPickerScreen({
    super.key,
    required this.title,
    this.confirmLabel = 'Confirm location',
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
  });

  @override
  State<MapLocationPickerScreen> createState() =>
      _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  static const LatLng _defaultCenter = LatLng(19.0760, 72.8777);

  GoogleMapController? _mapController;
  late LatLng _selectedLatLng;
  String _address = '';
  bool _isResolvingAddress = false;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _selectedLatLng =
        widget.initialLatitude != null && widget.initialLongitude != null
            ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
            : _defaultCenter;
    _address = widget.initialAddress?.trim().isNotEmpty == true
        ? widget.initialAddress!.trim()
        : 'Move the map or tap a place';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialLatitude == null || widget.initialLongitude == null) {
        _useCurrentLocation(moveCamera: true);
      } else {
        _resolveAddress(_selectedLatLng);
      }
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation({bool moveCamera = true}) async {
    setState(() => _isLocating = true);
    final position = await LocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() => _isLocating = false);

    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to get current location')),
      );
      return;
    }

    final latLng = LatLng(position.latitude, position.longitude);
    setState(() => _selectedLatLng = latLng);
    if (moveCamera) {
      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 16),
        ),
      );
    }
    await _resolveAddress(latLng);
  }

  Future<void> _resolveAddress(LatLng latLng) async {
    setState(() => _isResolvingAddress = true);
    final address = await LocationService.getAddressFromCoordinates(
        latLng.latitude, latLng.longitude);
    if (!mounted) return;
    setState(() {
      _address = address?.trim().isNotEmpty == true
          ? address!.trim()
          : '${latLng.latitude.toStringAsFixed(6)}, ${latLng.longitude.toStringAsFixed(6)}';
      _isResolvingAddress = false;
    });
  }

  void _selectLocation(LatLng latLng) {
    setState(() => _selectedLatLng = latLng);
    _resolveAddress(latLng);
  }

  void _confirmSelection() {
    Navigator.pop(
      context,
      MapLocationResult(
        address: _address,
        latitude: _selectedLatLng.latitude,
        longitude: _selectedLatLng.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedLatLng,
              zoom: widget.initialLatitude == null ? 12 : 16,
            ),
            myLocationButtonEnabled: false,
            myLocationEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) => _mapController = controller,
            onTap: _selectLocation,
            markers: {
              Marker(
                markerId: const MarkerId('selected_location'),
                position: _selectedLatLng,
                draggable: true,
                onDragEnd: _selectLocation,
              ),
            },
          ),
          Positioned(
            right: 16,
            top: 16,
            child: FloatingActionButton.small(
              heroTag: 'map_picker_current_location',
              onPressed: _isLocating ? null : () => _useCurrentLocation(),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              child: _isLocating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border:
                Border(top: BorderSide(color: Theme.of(context).dividerColor)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isResolvingAddress ? 'Finding address...' : _address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isResolvingAddress ? null : _confirmSelection,
                  icon: const Icon(Icons.check),
                  label: Text(widget.confirmLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
