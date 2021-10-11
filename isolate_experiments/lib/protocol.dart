import 'src/introspection/serializable.dart';

export 'src/introspection/serializable.dart';

class RunMacroRequest {
  final String identifier;
  final Map<String, Object?> arguments;
  final Serializable declaration;

  RunMacroRequest(this.identifier, this.arguments, this.declaration);

  RunMacroRequest.fromJson(Map<String, Object?> json)
      : arguments = json['arguments'] as Map<String, Object?>,
        identifier = json['identifier'] as String,
        declaration =
            deserializeDeclaration(json['declaration'] as Map<String, Object?>);

  Map<String, Object?> toJson() => {
        'arguments': arguments,
        'identifier': identifier,
        'declaration': declaration.toJson(),
      };
}

class RunMacroResponse {
  final String generatedCode;

  RunMacroResponse(this.generatedCode);

  RunMacroResponse.fromJson(Map<String, Object?> json)
      : generatedCode = json['generatedCode'] as String;

  Map<String, Object?> toJson() => {'generatedCode': generatedCode};
}

class TypeReferenceDescriptor {
  final String libraryUri;
  final String name;
  final List<TypeReferenceDescriptor> typeArguments;

  TypeReferenceDescriptor(this.libraryUri, this.name,
      {this.typeArguments = const []});

  TypeReferenceDescriptor.fromJson(Map<String, Object?> json)
      : libraryUri = json['libraryUri'] as String,
        name = json['name'] as String,
        typeArguments = [
          for (var typeArgJson in json['typeArguments'] as List)
            TypeReferenceDescriptor.fromJson(
                typeArgJson as Map<String, Object?>),
        ];

  Map<String, Object?> toJson() => {
        'libraryUri': libraryUri,
        'name': name,
        'typeArguments': [
          for (var arg in typeArguments) arg.toJson(),
        ],
      };
}

class ReflectTypeRequest {
  final TypeReferenceDescriptor descriptor;

  ReflectTypeRequest(this.descriptor);

  ReflectTypeRequest.fromJson(Map<String, Object?> json)
      : descriptor = TypeReferenceDescriptor.fromJson(
            json['descriptor'] as Map<String, Object?>);

  Map<String, Object?> toJson() => {
        'descriptor': descriptor.toJson(),
      };
}

class ReflectTypeResponse<T extends Serializable> {
  final T declaration;

  ReflectTypeResponse(this.declaration);

  ReflectTypeResponse.fromJson(Map<String, Object?> json)
      : declaration =
            deserializeDeclaration(json['declaration'] as Map<String, Object?>);

  Map<String, Object?> toJson() => {
        'declaration': declaration.toJson(),
      };
}

abstract class Serializable {
  Map<String, Object?> toJson();
}

/// This must be assigned by an implementation.
ReflectTypeResponse<T> Function<T extends Serializable>(
        ReflectTypeRequest request)
    // ignore: prefer_function_declarations_over_variables
    reflectType = <T extends Serializable>(_) => throw UnimplementedError();
