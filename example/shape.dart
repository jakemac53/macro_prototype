// GENERATED FILE - DO NOT EDIT
//
// This file was generated by applying the following macros to the
// `example/shape.declarations.dart` file:
//
//   - Instance of '_JsonMacro'
//
// To make changes you should edit the `example/shape.gen.dart` file;

import 'macros/freezed.dart';

abstract class ShapeCircle extends Shape {
  @override
  Map<String, Object?> toJson() {
    return {"radius": radius, "debugLabel": debugLabel};
  }

  @override
  ShapeCircle copyWith({double radius, String? debugLabel});
  ShapeCircle._() : super._();
  factory ShapeCircle(double radius, {String? debugLabel}) = _$ShapeCircle;
  factory ShapeCircle.fromJson(Map<String, Object?> json) {
    return ShapeCircle(json["radius"] as double,
        debugLabel: json["debugLabel"] as String?);
  }
  double get radius;
  @override
  String? get debugLabel;
}

class _$ShapeCircle extends ShapeCircle {
  @override
  final double radius;
  @override
  final String? debugLabel;
  @override
  R when<R>(
      {required R Function(double radius, String? debugLabel) circle,
      required R Function(double width, double height, String? debugLabel)
          rectangle}) {
    return circle(radius, debugLabel);
  }

  @override
  _$ShapeCircle copyWith(
      {Object? radius = const Default(),
      Object? debugLabel = const Default()}) {
    return _$ShapeCircle(
        radius == const Default() ? this.radius : radius as double,
        debugLabel: debugLabel == const Default()
            ? this.debugLabel
            : debugLabel as String?);
  }

  @override
  bool operator ==(Object other) {
    return runtimeType == other.runtimeType &&
        other is _$ShapeCircle &&
        other.radius == radius &&
        other.debugLabel == debugLabel;
  }

  @override
  String toString() {
    return 'ShapeCircle(radius: $radius, debugLabel: $debugLabel)';
  }

  _$ShapeCircle(this.radius, {this.debugLabel}) : super._();
  @override
  int get hashCode => Object.hashAll([runtimeType, radius, debugLabel]);
}

abstract class ShapeRectangle extends Shape {
  @override
  Map<String, Object?> toJson() {
    return {"width": width, "height": height, "debugLabel": debugLabel};
  }

  @override
  ShapeRectangle copyWith({double width, double height, String? debugLabel});
  ShapeRectangle._() : super._();
  factory ShapeRectangle(
      {required double width,
      required double height,
      String? debugLabel}) = _$ShapeRectangle;
  factory ShapeRectangle.fromJson(Map<String, Object?> json) {
    return ShapeRectangle(
        width: json["width"] as double,
        height: json["height"] as double,
        debugLabel: json["debugLabel"] as String?);
  }
  double get width;
  double get height;
  @override
  String? get debugLabel;
}

class _$ShapeRectangle extends ShapeRectangle {
  @override
  final double width;
  @override
  final double height;
  @override
  final String? debugLabel;
  @override
  R when<R>(
      {required R Function(double radius, String? debugLabel) circle,
      required R Function(double width, double height, String? debugLabel)
          rectangle}) {
    return rectangle(width, height, debugLabel);
  }

  @override
  _$ShapeRectangle copyWith(
      {Object? width = const Default(),
      Object? height = const Default(),
      Object? debugLabel = const Default()}) {
    return _$ShapeRectangle(
        width: width == const Default() ? this.width : width as double,
        height: height == const Default() ? this.height : height as double,
        debugLabel: debugLabel == const Default()
            ? this.debugLabel
            : debugLabel as String?);
  }

  @override
  bool operator ==(Object other) {
    return runtimeType == other.runtimeType &&
        other is _$ShapeRectangle &&
        other.width == width &&
        other.height == height &&
        other.debugLabel == debugLabel;
  }

  @override
  String toString() {
    return 'ShapeRectangle(width: $width, height: $height, debugLabel: $debugLabel)';
  }

  _$ShapeRectangle({required this.width, required this.height, this.debugLabel})
      : super._();
  @override
  int get hashCode => Object.hashAll([runtimeType, width, height, debugLabel]);
}

@freezed
abstract class Shape {
  Shape copyWith({String? debugLabel});
  R when<R>(
      {required R Function(double radius, String? debugLabel) circle,
      required R Function(double width, double height, String? debugLabel)
          rectangle});
  Map<String, Object?> toJson();
  String toPrettyString() {
    return when(
        circle: (radius, _) => '$debugLabel: Circle radius $radius',
        rectangle: (width, height, _) =>
            '$debugLabel: Rectangle width $width height $height');
  }

  Shape._();
  factory Shape.fromJson(Map<String, Object?> json) {
    switch (json['type'] as String?) {
      case "circle":
        return ShapeCircle.fromJson(json);
      case "rectangle":
        return ShapeRectangle.fromJson(json);
      default:
        throw FallThroughError();
    }
  }
  factory Shape.circle(double radius, {String? debugLabel}) = ShapeCircle;
  factory Shape.rectangle(
      {required double width,
      required double height,
      String? debugLabel}) = ShapeRectangle;
  String? get debugLabel;
}
