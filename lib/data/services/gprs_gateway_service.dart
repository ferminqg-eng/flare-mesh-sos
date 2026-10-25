import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Pasarela oportunista GPRS / 2G.
///
/// Cuando el nodo emisor o cualquier nodo puente ciego (Blind Relay) alcanza una
/// celda con cobertura móvil mínima (2G/GPRS/EDGE/3G/LTE), despacha exactamente
/// el mismo buffer binario crudo de 18 bytes (`application/octet-stream`) para
/// minimizar consumo de ancho de banda y soportar enlaces de alta latencia (>1500 ms).
class GprsGatewayService {
  GprsGatewayService({
    Uri? gatewayEndpoint,
    http.Client? httpClient,
  })  : _gatewayEndpoint = gatewayEndpoint ?? Uri.parse('https://relay.flaremesh.example/v1/ingest'),
        _httpClient = httpClient ?? http.Client();

  final Uri _gatewayEndpoint;
  final http.Client _httpClient;

  /// Intenta subir los 18 bytes por red celular/GPRS sin bloquear la retransmisión BLE.
  Future<bool> tryForwardBinaryPacket(Uint8List raw18Bytes) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final hasRadioLink = connectivity.any(
        (result) =>
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.ethernet,
      );
      if (!hasRadioLink) return false;

      final response = await _httpClient
          .post(
            _gatewayEndpoint,
            headers: const <String, String>{
              'Content-Type': 'application/octet-stream',
              'X-Mesh-Protocol': '1',
            },
            body: raw18Bytes,
          )
          .timeout(const Duration(seconds: 8)); // Timeout tolerante a latencia 2G/GPRS

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      // Entorno puramente off-grid o enlace GPRS caído: la malla BLE continúa operando.
      return false;
    }
  }
}
