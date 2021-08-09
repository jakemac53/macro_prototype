import 'dart:convert';

import 'observable.dart';
import 'shape.dart';
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

  print('\n--- freezed macro ---\n');

  final circle = Shape.circle(42, debugLabel: 'circle');
  print('circle: $circle');

  final rectangle =
      Shape.rectangle(width: 42, height: 21, debugLabel: 'rectangle');
  print('rectangle: $rectangle');
  final decodedCircle = Shape.fromJson({
    'type': 'circle',
    'radius': 42.0,
    'debugLabel': 'circle',
  });
  print('decodedCircle: $decodedCircle');
  print('circle == decodedCircle: ${circle == decodedCircle}');

  final decodedRectangle = Shape.fromJson({
    'type': 'rectangle',
    'width': 1.0,
    'height': 2.0,
  });
  print('decodedRectangle: $decodedRectangle');
  print('rectangle == decodedRectangle: ${rectangle == decodedRectangle}');

  printShape(circle);
  printShape(rectangle);
  printShape(decodedCircle);
  printShape(decodedRectangle);

  final fooCircle = circle.copyWith(debugLabel: 'foo');
  print('copy `circle` with label "foo": $fooCircle');

  final fooRectangle = rectangle.copyWith(debugLabel: 'foo');
  print('copy `rectangle` with label "foo": $fooRectangle');

  final nullCircle = circle.copyWith(debugLabel: null);
  print('copy `circle` with label null: $nullCircle');
}

void printShape(Shape shape) {
  shape.when(
    circle: (radius, label) => print('when $label: Circle radius $radius'),
    rectangle: (width, height, label) => print(
      'when $label: Rectangle width $width height $height',
    ),
  );
}
