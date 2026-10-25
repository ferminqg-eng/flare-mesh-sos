/// Contacto de emergencia seleccionado desde la agenda con clave anti-usurpación.
class EmergencyContact {
  const EmergencyContact({
    required this.displayName,
    required this.rawPhone,
    required this.phoneUint64,
    this.verificationPin = '1234',
  });

  final String displayName;
  final String rawPhone;

  /// Representación numérica uint64 limpia para cruce O(1) con el payload BLE.
  final int phoneUint64;

  /// PIN secreto de 4 dígitos acordado con este contacto para validar autenticidad (Anti-Spoofing).
  final String verificationPin;

  /// Normaliza cualquier cadena telefónica ("+58 (412) 555-0199") a entero uint64.
  static int? parsePhoneToUint64(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 7 || digitsOnly.length > 18) {
      return null;
    }
    return int.tryParse(digitsOnly);
  }

  /// Compara dos IDs telefónicos de forma exacta o por sufijo nacional (últimos 9 dígitos).
  bool matchesSender(int incomingSenderPhone) {
    if (phoneUint64 == incomingSenderPhone) return true;
    final a = phoneUint64.toString();
    final b = incomingSenderPhone.toString();
    if (a.length >= 9 && b.length >= 9) {
      return a.substring(a.length - 9) == b.substring(b.length - 9);
    }
    return false;
  }

  /// Calcula el token de autenticación uint16 (2 bytes) para un paquete emitido por este contacto.
  int computeExpectedAuthTag({
    required int senderPhone,
    required int emergencyCode,
    required int messageId,
  }) {
    final pinInt = int.tryParse(verificationPin) ?? 1234;
    // Hash polinomial de 16 bits rápido sin dependencias pesadas
    var hash = 0x811C;
    hash = (hash ^ (senderPhone & 0xFFFF)) * 0x0103;
    hash = (hash ^ ((senderPhone >> 16) & 0xFFFF)) * 0x0103;
    hash = (hash ^ emergencyCode) * 0x0103;
    hash = (hash ^ messageId) * 0x0103;
    hash = (hash ^ pinInt) * 0x0103;
    return hash & 0xFFFF;
  }

  EmergencyContact copyWith({
    String? displayName,
    String? rawPhone,
    int? phoneUint64,
    String? verificationPin,
  }) {
    return EmergencyContact(
      displayName: displayName ?? this.displayName,
      rawPhone: rawPhone ?? this.rawPhone,
      phoneUint64: phoneUint64 ?? this.phoneUint64,
      verificationPin: verificationPin ?? this.verificationPin,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'displayName': displayName,
        'rawPhone': rawPhone,
        'phoneUint64': phoneUint64,
        'verificationPin': verificationPin,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      displayName: json['displayName'] as String,
      rawPhone: json['rawPhone'] as String,
      phoneUint64: (json['phoneUint64'] as num).toInt(),
      verificationPin: (json['verificationPin'] as String?) ?? '1234',
    );
  }
}
