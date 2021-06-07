import 'user.dart';

void main() {
  var user = User(name: 'jake');
  print(user.toJson());
  user.name = 'john';
  user.name = 'jill';
  print(user.toJson());
}
