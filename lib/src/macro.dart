import 'code.dart';
import 'declarations.dart';
import 'definitions.dart';
import 'types.dart';

/// The marker interface for all types of macros.
abstract class Macro {}

/// The marker interface for macros that are allowed to contribute new type
/// declarations into the program.
///
/// These macros run before all other types of macros.
///
/// In exchange for the power to add new type declarations, these macros have
/// limited introspections capabilities, since new types can be added in this
/// phase you cannot follow type references back to their declarations.
abstract class TypeMacro implements Macro {}

/// The marker interface for macros that are allowed to contribute new
/// declarations to the program, including both top level and class level
/// declarations.
///
/// These macros run after [Typemacro] macros, but before [DefinitionMacro]
/// macros.
///
/// These macros can resolve type annotations to specific declarations, and
/// inspect type hierarchies, but they cannot inspect the declarations on those
/// type annotations, since new declarations could still be added in this phase.
abstract class DeclarationMacro implements Macro {}

/// The marker interface for macros that are only allowed to implement or wrap
/// existing declarations in the program. They cannot introduce any new
/// declarations that are visible to the program, but are allowed to add
/// declarations that only they can see.
///
/// These macros run after all other types of macros.
///
/// These macros can fully reflect on the program since the static shape is
/// fully definied by the time they run.
abstract class DefinitionMacro implements Macro {}

/// The interface for [TypeMacro]s that can be applied to classes.
abstract class ClassTypeMacro implements TypeMacro {
  void visitClassType(ClassType type, TypeBuilder builder);
}

/// The interface for [DeclarationMacro]s that can be applied to classes.
abstract class ClassDeclarationMacro implements DeclarationMacro {
  void visitClassDeclaration(
      ClassDeclaration declaration, ClassDeclarationBuilder builder);
}

/// The interface for [TypeMacro]s that can be applied to fields.
abstract class FieldTypeMacro implements TypeMacro {
  void visitFieldType(FieldType type, TypeBuilder builder);
}

/// The interface for [DeclarationMacro]s that can be applied to fields.
abstract class FieldDeclarationMacro implements DeclarationMacro {
  void visitFieldDeclaration(
      FieldDeclaration declaration, ClassDeclarationBuilder builder);
}

/// The interface for [DefinitionMacro]s that can be applied to fields.
abstract class FieldDefinitionMacro implements DefinitionMacro {
  void visitFieldDefinition(
      FieldDefinition definition, FieldDefinitionBuilder builder);
}

/// The interface for [TypeMacro]s that can be applied to top level functions
/// or methods.
abstract class FunctionTypeMacro implements TypeMacro {
  void visitFunctionType(FunctionType type, TypeBuilder builder);
}

/// The interface for [DeclarationMacro]s that can be applied to top level
/// functions or methods.
abstract class FunctionDeclarationMacro implements DeclarationMacro {
  void visitFunctionDeclaration(
      FunctionDeclaration declaration, DeclarationBuilder builder);
}

/// The interface for [DefinitionMacro]s that can be applied to top level
/// functions or methods.
abstract class FunctionDefinitionMacro implements DefinitionMacro {
  void visitFunctionDefinition(
      FunctionDefinition definition, FunctionDefinitionBuilder builder);
}

/// The interface for [TypeMacro]s that can be applied to methods.
abstract class MethodTypeMacro implements TypeMacro {
  void visitMethodType(MethodType type, TypeBuilder builder);
}

/// The interface for [DeclarationMacro]s that can be applied to methods.
abstract class MethodDeclarationMacro implements DeclarationMacro {
  void visitMethodDeclaration(
      MethodDeclaration declaration, ClassDeclarationBuilder builder);
}

/// The interface for [DefinitionMacro]s that can be applied to methods.
abstract class MethodDefinitionMacro implements DefinitionMacro {
  void visitMethodDefinition(
      MethodDefinition definition, FunctionDefinitionBuilder builder);
}

/// The interface for [TypeMacro]s that can be applied to constructors.
abstract class ConstructorTypeMacro implements TypeMacro {
  void visitConstructorType(ConstructorType type, TypeBuilder builder);
}

/// The interface for [DeclarationMacro]s that can be applied to constructors.
abstract class ConstructorDeclarationMacro implements DefinitionMacro {
  void visitConstructorDeclaration(
      ConstructorDeclaration declaration, ClassDeclarationBuilder builder);
}

/// The interface for [DefinitionMacro]s that can be applied to constructors.
abstract class ConstructorDefinitionMacro implements DefinitionMacro {
  void visitConstructorDefinition(
      ConstructorDefinition definition, ConstructorDefinitionBuilder builder);
}

/// The api used by [TypeMacro]s to contribute new type declarations to the
/// current library, and get [TypeReference]s from runtime [Type] objects.
abstract class TypeBuilder {
  /// Adds a new type declaration to the surrounding library.
  void addTypeToLibary(Declaration typeDeclaration);

  /// Used to construct a [TypeReference] to a runtime type available to the
  /// the macro implementation code.
  TypeReference typeReferenceOf<T>();
}

/// The api used by [DeclarationMacro]s to contribute new declarations to the
/// current library, and get [TypeDeclaration]s from runtime [Type] objects.
abstract class DeclarationBuilder {
  /// Adds a new regular declaration to the surrounding library.
  ///
  /// Note that type declarations are not supported.
  void addToLibrary(Declaration declaration);

  /// Used to construct a [TypeReference] to a runtime type available to the
  /// the macro implementation code.
  TypeDeclaration typeDeclarationOf<T>();
}

/// The api used by [DeclarationMacro]s to contribute new declarations to the
/// current class.
///
/// Note that this is available to macros that run directly on classes, as well
/// as macros that run on any members of a class.
abstract class ClassDeclarationBuilder implements DeclarationBuilder {
  /// Adds a new declaration to the surrounding class.
  void addToClass(Declaration declaration);
}

/// The api implemented by builder objects provided to [DefinitionMacro]s.
///
/// Each type of macro has its own specialized versions of this interface
/// depending on the type of declaration.
///
/// This is also used to create [TypeDefinition]s from runtime [Type] objects.
abstract class DefinitionBuilder {
  /// Used to construct a [TypeDefinition] to a runtime type available to the
  /// the macro implementation code.
  TypeDefinition typeDefinitionOf<T>();
}

/// The apis used by [DefinitionMacro]s to define the body of abstract or
/// external constructors, as well as wrap the body of concrete constructors
/// with additional statements.
///
/// Note that factory constructors should only provide a [body].
abstract class ConstructorDefinitionBuilder implements DefinitionBuilder {
  /// Used to implement a constructor with a combination of initializers and/or
  /// a constructor body.
  void implement({FunctionBody? body, List<Code>? initializers});

  /// Used to wrap the body of a function, by running some code before or after
  /// the original body.
  ///
  /// Note that the original function will not have access to code from [before]
  /// or [after], and also [after] will not have access to anything from the
  /// scope of the original function body. However, [before] and [after] do
  /// share the same scope, so [after] can reference variables defined in
  /// [before].
  ///
  /// You can conceptually think of the wrapping as implemented like this when
  /// understanding the semantics:
  ///
  /// ```dart
  /// void someFunction(int x) {
  ///   void originalFn(int x) {
  ///     // Copy the original function body here
  ///   }
  ///
  ///   // Inject all [before] code here.
  ///
  ///   // Call function matching the original, capture the return value to
  ///   // return later. Note that [ret] should not be available to [after].
  ///   var ret = originalFn(x);
  ///
  ///   // Inject all [after] code here.
  ///
  ///   return ret; // Return the original return value
  /// }
  /// ```
  ///
  /// Note that this means [before] can modify parameters before they are
  /// passed into the original function.
  void wrapBody({
    List<Statement>? before,
    List<Statement>? after,
  });
}

/// The apis used by [DefinitionMacro]s to define the body of abstract or
/// external functions (or methods), as well as wrap the body of concrete
/// functions or methods with additional statements.
abstract class FunctionDefinitionBuilder implements DefinitionBuilder {
  void implement(FunctionBody body, {List<Code>? supportingDeclarations});

  /// Used to wrap the body of a function, by running some code before or after
  /// the original body.
  ///
  /// Note that the original function will not have access to code from [before]
  /// or [after], and also [after] will not have access to anything from the
  /// scope of the original function body. However, [before] and [after] do
  /// share the same scope, so [after] can reference variables defined in
  /// [before].
  ///
  /// You can conceptually think of the wrapping as implemented like this when
  /// understanding the semantics:
  ///
  /// ```dart
  /// void someFunction(int x) {
  ///   void originalFn(int x) {
  ///     // Copy the original function body here
  ///   }
  ///
  ///   // Inject all [before] code here.
  ///
  ///   // Call function matching the original, capture the return value to
  ///   // return later. Note that [ret] should not be available to [after].
  ///   var ret = originalFn(x);
  ///
  ///   // Inject all [after] code here.
  ///
  ///   return ret; // Return the original return value
  /// }
  /// ```
  ///
  /// Note that this means [before] can modify parameters before they are
  /// passed into the original function.
  void wrapBody(
      {List<Statement>? before,
      List<Statement>? after,
      List<Declaration>? supportingDeclarations});
}

/// The api used by [DefinitionMacro]s to implement abstract or external
/// fields.
///
/// Note that concrete fields cannot be implemented in this way.
abstract class FieldDefinitionBuilder implements DefinitionBuilder {
  /// Implement this as a normal field and supply an initializer.
  void withInitializer(Expression body, {List<Code>? supportingDeclarations});

  /// Implement this as a getter/setter pair, with an optional new backing
  /// field.
  void withGetterSetterPair(Declaration getter, Declaration setter,
      {List<Code>? supportingDeclarations});
}
