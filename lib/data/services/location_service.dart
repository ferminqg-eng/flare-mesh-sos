import 'package:geolocator/geolocator.dart';

/// Servicio de geolocalización GPS con fallback resiliente para entornos off-grid.
class LocationService {
  /// Solicita permisos si es necesario y obtiene las coordenadas GPS actuales de alta precisión.
  Future<Position> getCurrentEmergencyPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const PermissionDeniedException('Permiso de ubicación denegado por el usuario.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const PermissionDeniedException(
        'Permiso de ubicación bloqueado permanentemente. Habilítalo en Ajustes.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
    } catch (_) {
      // En una emergencia real bajo techo/túnel donde el fix satelital demora,
      // recurrimos de inmediato a la última coordenada válida conocida en caché del chip GPS.
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return lastKnown;
      }
      rethrow;
    }
  }
}
