class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relationship;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.relationship = '',
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    final phone = json['phone'] as String?;
    if (name == null || name.isEmpty) {
      throw FormatException('EmergencyContact.fromJson: missing required field "name"');
    }
    if (phone == null || phone.isEmpty) {
      throw FormatException('EmergencyContact.fromJson: missing required field "phone"');
    }
    return EmergencyContact(
      id: json['id'] as String? ?? '',
      name: name,
      phone: phone,
      relationship: json['relationship'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'relationship': relationship,
  };

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? relationship,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relationship: relationship ?? this.relationship,
    );
  }
}
