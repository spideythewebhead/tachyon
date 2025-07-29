// AUTO GENERATED - DO NOT MODIFY
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, inference_failure_on_uninitialized_variable, inference_failure_on_function_return_type, inference_failure_on_untyped_parameter, deprecated_member_use_from_same_package
// coverage:ignore-file

part of 'example.dart';

extension UserCopyWithExtension on User {
  User copyWith({
    String? id,
    String? name,
    Address? address,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
    );
  }
}

extension AddressCopyWithExtension on Address {
  Address copyWith({
    String? line1,
    String? line2,
    String? zipCode,
  }) {
    return Address(
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      zipCode: zipCode ?? this.zipCode,
    );
  }
}
