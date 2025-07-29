class User {
  User({
    required this.id,
    required this.name,
    this.address,
  });

  final String id;
  final String name;
  final Address? address;
}

class Address {
  Address({
    required this.line1,
    required this.line2,
    required this.zipCode,
  });

  final String line1;
  final String? line2;
  final String zipCode;
}
