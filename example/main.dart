import 'dart:convert';

import 'observable.dart';
import 'user.dart';

void main() {
  var jake = User(name: 'jake');
  print('toString: $jake');
  print('jsonEncode(jake.toJson()): ${jsonEncode(jake.toJson())}');
  var user2 = User.fromJson(jake.toJson());
  print('round trip user equality: '
      '${jsonEncode(user2.toJson()) == jsonEncode(jake.toJson())}');

  var group = Group(name: 'just ${jake.name}', users: [jake]);
  print('jsonEncode(group.toJson()): ${jsonEncode(group.toJson())}');
  var group2 = Group.fromJson(group.toJson());

  print('round trip group equality: '
      '${jsonEncode(group2.toJson()) == jsonEncode(group.toJson())}');

  var manager = Manager(name: 'leaf', reports: [jake]);
  print('jsonEncode(manager.toJson()): ${jsonEncode(manager.toJson())}');
  var manager2 = Manager.fromJson(manager.toJson());
  print('round trip manager equality: '
      '${jsonEncode(manager2.toJson()) == jsonEncode(manager.toJson())}');

  var observable = ObservableThing('hello');
  print('changing property of observable property:');
  observable.description = 'world';

  var george = jake.copyWith(name: 'george');
  print('jake.copyWith(name: \'george\') => $george');
  print('george == jake => ${george == jake}');
  print('jake == jake.copyWith() => ${jake == jake.copyWith()}');
  print('george.hashCode => ${george.hashCode}');
}
