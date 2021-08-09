import 'macros/data_class.dart';
import 'macros/freezed.dart';
import 'macros/json.dart';

@freezed
abstract class Shape {
  factory Shape.circle(double radius, {String? debugLabel}) = ShapeCircle;

  factory Shape.rectangle({
    required double width,
    required double height,
    String? debugLabel,
  }) = ShapeRectangle;

  void prettyPrint() {
    when(
      circle: (radius, _) => print('when $debugLabel: Circle radius $radius'),
      rectangle: (width, height, _) => print(
        'when $debugLabel: Rectangle width $width height $height',
      ),
    );
  }
}
