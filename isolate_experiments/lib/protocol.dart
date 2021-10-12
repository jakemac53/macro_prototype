import 'package:collection/collection.dart';
import 'package:macro_builder/macros/data_class.dart';

import 'src/introspection/serializable.dart';

export 'src/introspection/serializable.dart';
export 'src/builders/builders.dart';

enum Phase {
  type,
  declaration,
  definition,
}

class RunMacroRequest {
  final String identifier;
  final Map<String, Object?> arguments;
  final DeclarationDescriptor declarationDescriptor;
  final Phase phase;

  RunMacroRequest(
      this.identifier, this.arguments, this.declarationDescriptor, this.phase);

  RunMacroRequest.fromJson(Map<String, Object?> json)
      : arguments = json['arguments'] as Map<String, Object?>,
        identifier = json['identifier'] as String,
        declarationDescriptor = DeclarationDescriptor.fromJson(
            json['declarationDescriptor'] as Map<String, Object?>),
        phase = Phase.values[json['phase'] as int];

  Map<String, Object?> toJson() => {
        'arguments': arguments,
        'identifier': identifier,
        'declarationDescriptor': declarationDescriptor.toJson(),
        'phase': phase.index,
        'type': 'RunMacroRequest',
      };
}

class RunMacroResponse {
  final String generatedCode;

  RunMacroResponse(this.generatedCode);

  RunMacroResponse.fromJson(Map<String, Object?> json)
      : generatedCode = json['generatedCode'] as String;

  Map<String, Object?> toJson() => {
        'generatedCode': generatedCode,
        'type': 'RunMacroResponse',
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
        'type': 'ReflectTypeRequest',
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
        'type': 'ReflectTypeResponse',
      };
}

class GetDeclarationRequest {
  final DeclarationDescriptor descriptor;

  GetDeclarationRequest(this.descriptor);

  GetDeclarationRequest.fromJson(Map<String, Object?> json)
      : descriptor = DeclarationDescriptor.fromJson(
            json['descriptor'] as Map<String, Object?>);

  Map<String, Object?> toJson() => {
        'descriptor': descriptor.toJson(),
        'type': 'GetDeclarationRequest',
      };
}

class GetDeclarationResponse {
  final Serializable declaration;
  GetDeclarationResponse(this.declaration);

  GetDeclarationResponse.fromJson(Map<String, Object?> json)
      : declaration =
            deserializeDeclaration(json['declaration'] as Map<String, Object?>);

  Map<String, Object?> toJson() => {
        'declaration': declaration.toJson(),
        'type': 'GetDeclarationResponse',
      };
}

enum DeclarationType {
  clazz,
  field,
  method,
  constructor,
}

class DeclarationDescriptor {
  final String libraryUri;
  final String? parentType;
  final String name;
  final DeclarationType declarationType;

  DeclarationDescriptor(
      this.libraryUri, this.parentType, this.name, this.declarationType);

  DeclarationDescriptor.fromJson(Map<String, Object?> json)
      : libraryUri = json['libraryUri'] as String,
        parentType = json['parentType'] as String?,
        name = json['name'] as String,
        declarationType =
            DeclarationType.values[json['declarationType'] as int];

  Map<String, Object?> toJson() => {
        'libraryUri': libraryUri,
        if (parentType != null) 'parentType': parentType,
        'name': name,
        'declarationType': declarationType.index,
      };

  @override
  bool operator ==(Object other) =>
      other is DeclarationDescriptor &&
      other.declarationType == declarationType &&
      other.name == name &&
      other.parentType == parentType &&
      other.libraryUri == libraryUri;

  @override
  int get hashCode =>
      Object.hash(declarationType, name, parentType, libraryUri);
}

class TypeReferenceDescriptor {
  final String libraryUri;
  final String name;
  final bool isNullable;
  final List<TypeReferenceDescriptor> typeArguments;

  TypeReferenceDescriptor(this.libraryUri, this.name, this.isNullable,
      {this.typeArguments = const []});

  TypeReferenceDescriptor.fromJson(Map<String, Object?> json)
      : libraryUri = json['libraryUri'] as String,
        name = json['name'] as String,
        isNullable = json['isNullable'] as bool,
        typeArguments = [
          for (var typeArgJson in json['typeArguments'] as List)
            TypeReferenceDescriptor.fromJson(
                typeArgJson as Map<String, Object?>),
        ];

  Map<String, Object?> toJson() => {
        'libraryUri': libraryUri,
        'name': name,
        'isNullable': isNullable,
        'typeArguments': [
          for (var arg in typeArguments) arg.toJson(),
        ],
      };

  @override
  bool operator ==(Object other) =>
      other is TypeReferenceDescriptor &&
      other.libraryUri == libraryUri &&
      other.name == name &&
      other.isNullable == isNullable &&
      const DeepCollectionEquality().equals(other.typeArguments, typeArguments);

  @override
  int get hashCode =>
      Object.hashAll([libraryUri, name, isNullable, ...typeArguments]);
}

abstract class Serializable {
  Map<String, Object?> toJson();
}

/// This must be assigned by an implementation.
ReflectTypeResponse<T> Function<T extends Serializable>(
        ReflectTypeRequest request)
    // ignore: prefer_function_declarations_over_variables
    reflectType = <T extends Serializable>(_) => throw UnimplementedError();
