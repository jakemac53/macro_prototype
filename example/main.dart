import 'dart:convert';

import 'observable.dart';
import 'user.dart';

void main() {
  var user = User(name: 'jake');
  print(user.toJson());
  var user2 = User.fromJson(user.toJson());
  assert(jsonEncode(user2.toJson()) == jsonEncode(user.toJson()));

  var group = Group(name: 'just ${user.name}', users: [user]);
  print(group.toJson());
  var group2 = Group.fromJson(group.toJson());
  assert(jsonEncode(group2.toJson()) == jsonEncode(group.toJson()));

  var manager = Manager(name: 'leaf', reports: [user]);
  print(manager.toJson());
  var manager2 = Manager.fromJson(manager.toJson());
  assert(jsonEncode(manager2.toJson()) == jsonEncode(manager.toJson()));

  var observable = new ObservableThing('hello');
  observable.description = 'world';
}
