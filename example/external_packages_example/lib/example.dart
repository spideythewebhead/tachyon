import 'package:external_packages_example/generator/annotations.dart';
import 'package:random_classes/random_classes.dart';

part 'example.gen.dart';

// This will generate a "copyWith" extension for external package "random_classes"

@CopyWith()
void main() {
  final User user = User(id: '1', name: 'Pantelis');
  print(user
      .copyWith(address: Address(line1: 'Line 1 set by "copyWith"', line2: 'Line2', zipCode: '123'))
      .address
      ?.line1);
}
