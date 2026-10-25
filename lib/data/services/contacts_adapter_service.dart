import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/models/emergency_contact.dart';

/// Adaptador de agenda nativa Android/iOS compatible con Dart 3 y Android Embedding v2.
class ContactsAdapterService {
  Future<List<EmergencyContact>> fetchDeviceContacts() async {
    final status = await Permission.contacts.request();
    if (!status.isGranted) {
      throw StateError('Se requiere permiso de Contactos para elegir tus 4 contactos SOS.');
    }

    final List<Contact> rawContacts = await FlutterContacts.getAll(
      properties: const <ContactProperty>{
        ContactProperty.name,
        ContactProperty.phone,
      },
    );

    final List<EmergencyContact> parsed = <EmergencyContact>[];
    final Set<int> seenIds = <int>{};

    for (final contact in rawContacts) {
      final name = (contact.displayName ?? '').trim();
      if (name.isEmpty || contact.phones.isEmpty) continue;

      for (final phoneItem in contact.phones) {
        final rawValue = (phoneItem.normalizedNumber ?? phoneItem.number).trim();
        final uint64Id = EmergencyContact.parsePhoneToUint64(rawValue);
        if (uint64Id != null && seenIds.add(uint64Id)) {
          parsed.add(
            EmergencyContact(
              displayName: name,
              rawPhone: phoneItem.number.trim().isNotEmpty ? phoneItem.number.trim() : rawValue,
              phoneUint64: uint64Id,
            ),
          );
        }
      }
    }

    parsed.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return parsed;
  }
}
