import 'dart:convert';

import 'observable.dart';
import 'user.dart';

void main() {
  var user = User('jake');
  print(user.toJson());
  var user2 = User.fromJson(user.toJson());
  assert(jsonEncode(user2.toJson()) == jsonEncode(user.toJson()));

  var group = Group('just ${user.name}', [user]);
  print(group.toJson());
  var group2 = Group.fromJson(group.toJson());
  assert(jsonEncode(group2.toJson()) == jsonEncode(group.toJson()));

  var manager = Manager('leaf', [user]);
  print(manager.toJson());
  var manager2 = Manager.fromJson(manager.toJson());
  assert(jsonEncode(manager2.toJson()) == jsonEncode(manager.toJson()));

  var observable = WithObservableField('hello');
  observable.description = 'world';

  var observableClass = ObservableClass('jake', 'is pretty cool');
  observableClass
    ..name = 'john'
    ..description = 'is also cool';
}
