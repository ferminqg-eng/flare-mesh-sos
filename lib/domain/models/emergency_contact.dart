/// Contacto de emergencia seleccionado desde la agenda nativa (máximo 4).
class EmergencyContact {
  const EmergencyContact({
    required this.displayName,
    required this.rawPhone,
    required this.phoneUint64,
  });

  final String displayName;
  final String rawPhone;

  /// Representación numérica uint64 limpia para cruce O(1) con el payload BLE.
  final int phoneUint64;

  /// Normaliza cualquier cadena telefónica ("+58 (412) 555-0199") a entero uint64.
  static int? parsePhoneToUint64(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 7 || digitsOnly.length > 18) {
      return null;
    }
    return int.tryParse(digitsOnly);
  }

  /// Compara dos IDs telefónicos de forma exacta o por sufijo nacional (últimos 9 dígitos)
  /// para tolerar diferencias de prefijo internacional (+58 vs 0) en la agenda local.
  bool matchesSender(int incomingSenderPhone) {
    if (phoneUint64 == incomingSenderPhone) return true;
    final a = phoneUint64.toString();
    final b = incomingSenderPhone.toString();
    if (a.length >= 9 && b.length >= 9) {
      return a.substring(a.length - 9) == b.substring(b.length - 9);
    }
    return false;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'displayName': displayName,
        'rawPhone': rawPhone,
        'phoneUint64': phoneUint64,
      };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      displayName: json['displayName'] as String,
      rawPhone: json['rawPhone'] as String,
      phoneUint64: (json['phoneUint64'] as num).toInt(),
    );
  }
}
