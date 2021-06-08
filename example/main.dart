import 'user.dart';

void main() {
  var user = User('jake');
  print(user.toJson());
  user.name = 'john';
  user.name = 'jill';
  print(user.toJson());

  var group = Group('just ${user.name}', [user]);
  print(group.toJson());

  var manager = Manager('leaf', [user]);
  print(manager.toJson());
}
