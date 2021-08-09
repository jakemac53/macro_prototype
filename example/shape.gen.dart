import 'macros/freezed.dart';

@freezed
abstract class Shape {
  factory Shape.circle(double radius, {String? debugLabel}) = ShapeCircle;

  factory Shape.rectangle({
    required double width,
    required double height,
    String? debugLabel,
  }) = ShapeRectangle;

  String toPrettyString() {
    return when(
      circle: (radius, _) => 'when $debugLabel: Circle radius $radius',
      rectangle: (width, height, _) =>
          'when $debugLabel: Rectangle width $width height $height',
    );
  }
}
