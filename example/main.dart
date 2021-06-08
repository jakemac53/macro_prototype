import 'user.dart';

void main() {
  var user = User(name: 'jake');
  print(user.toJson());
  user.name = 'john';
  user.name = 'jill';
  print(user.toJson());

  var group = Group(name: 'just Jake', users: [user]);
  print(group.toJson());
}
