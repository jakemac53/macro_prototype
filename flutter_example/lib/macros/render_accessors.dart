import 'package:macro_builder/definition.dart';

class RenderAccessors implements FieldDeclarationMacro {
  const RenderAccessors({
    this.needsPaint = false,
    this.needsLayout = false,
    this.needsSemantics = false,
  });

  final bool needsPaint;
  final bool needsLayout;
  final bool needsSemantics;

  @override
  void visitFieldDeclaration(
    FieldDeclaration declaration,
    ClassDeclarationBuilder builder,
  ) {
    // TODO(goderbauer): Check that the annotated field is inside a RenderObject. How?
    if (!declaration.name.startsWith('_')) {
      throw ArgumentError(
        'GenRenderAccessors can only be used on private fields.',
      );
    }
    String privateName = declaration.name;
    String publicName = privateName.substring(1);
    String type = declaration.type.toCode();

    // Getter
    builder.addToClass(Declaration('$type get $publicName => $privateName;'));

    // Setter
    builder.addToClass(Declaration('''
      set $publicName($type value) {
        if (value == $privateName) {
          return;
        }
        $privateName = value;
        ${needsPaint ? 'markNeedsPaint();' : ''}
        ${needsLayout ? 'markNeedsLayout();' : ''}
        ${needsSemantics ? 'markNeedsSemanticsUpdate();' : ''}
      }
    '''));
  }
}
