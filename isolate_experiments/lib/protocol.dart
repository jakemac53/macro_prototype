import 'package:collection/collection.dart';
import 'package:messagepack/messagepack.dart';

import 'src/introspection/packable.dart';

export 'src/introspection/packable.dart';
export 'src/builders/builders.dart';

enum Phase {
  type,
  declaration,
  definition,
}

class RunMacroRequest implements Packable {
  final Map<String, Object?> arguments;
  final String identifier;
  final Phase phase;
  final DeclarationDescriptor declarationDescriptor;

  RunMacroRequest(
      this.identifier, this.arguments, this.declarationDescriptor, this.phase);

  RunMacroRequest.unpack(Unpacker unpacker)
      : arguments = unpacker.unpackMap().cast(),
        identifier = unpacker.unpackString()!,
        phase = Phase.values[unpacker.unpackInt()!],
        declarationDescriptor = DeclarationDescriptor.unpack(unpacker);

  @override
  void pack(Packer packer) {
    packer.packMapLength(arguments.length);
    if (arguments.isNotEmpty) {
      throw UnsupportedError('Macro arguments not supported yet');
    }
    packer
      ..packString(identifier)
      ..packInt(phase.index);
    declarationDescriptor.pack(packer);
  }
}

class RunMacroResponse implements Packable {
  final String generatedCode;

  RunMacroResponse(this.generatedCode);

  RunMacroResponse.unpack(Unpacker unpacker)
      : generatedCode = unpacker.unpackString()!;

  @override
  void pack(Packer packer) => packer.packString(generatedCode);
}

class ReflectTypeRequest implements Packable {
  final TypeReferenceDescriptor descriptor;

  ReflectTypeRequest(this.descriptor);

  ReflectTypeRequest.unpack(Unpacker unpacker)
      : descriptor = TypeReferenceDescriptor.unpack(unpacker);

  @override
  void pack(Packer packer) => descriptor.pack(packer);
}

class ReflectTypeResponse<T extends Packable> implements Packable {
  final T declaration;

  ReflectTypeResponse(this.declaration);

  ReflectTypeResponse.unpack(Unpacker unpacker)
      : declaration = unpackDeclaration(unpacker);

  @override
  void pack(Packer packer) => packDeclaration(declaration, packer);
}

class GetDeclarationRequest implements Packable {
  final DeclarationDescriptor descriptor;

  GetDeclarationRequest(this.descriptor);

  GetDeclarationRequest.unpack(Unpacker unpacker)
      : descriptor = DeclarationDescriptor.unpack(unpacker);

  @override
  void pack(Packer packer) => descriptor.pack(packer);
}

class GetDeclarationResponse implements Packable {
  final Packable declaration;

  GetDeclarationResponse(this.declaration);

  GetDeclarationResponse.unpack(Unpacker unpacker)
      : declaration = unpackDeclaration(unpacker);

  @override
  void pack(Packer packer) => packDeclaration(declaration, packer);
}

enum DeclarationType {
  clazz,
  field,
  method,
  constructor,
}

class DeclarationDescriptor implements Packable {
  final String libraryUri;
  final String? parentType;
  final String name;
  final DeclarationType declarationType;

  DeclarationDescriptor(
      this.libraryUri, this.parentType, this.name, this.declarationType);

  DeclarationDescriptor.unpack(Unpacker unpacker)
      : libraryUri = unpacker.unpackString()!,
        parentType = unpacker.unpackString(),
        name = unpacker.unpackString()!,
        declarationType = DeclarationType.values[unpacker.unpackInt()!];

  @override
  void pack(Packer packer) => packer
    ..packString(libraryUri)
    ..packString(parentType)
    ..packString(name)
    ..packInt(declarationType.index);

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

class TypeReferenceDescriptor implements Packable {
  final String libraryUri;
  final String name;
  final bool isNullable;
  final List<TypeReferenceDescriptor> typeArguments;

  TypeReferenceDescriptor(this.libraryUri, this.name, this.isNullable,
      {this.typeArguments = const []});

  TypeReferenceDescriptor.unpack(Unpacker unpacker)
      : libraryUri = unpacker.unpackString()!,
        name = unpacker.unpackString()!,
        isNullable = unpacker.unpackBool()!,
        typeArguments = (() {
          var length = unpacker.unpackListLength();
          return [
            for (var i = 0; i < length; i++)
              TypeReferenceDescriptor.unpack(unpacker)
          ];
        })();

  @override
  void pack(Packer packer) {
    packer
      ..packString(libraryUri)
      ..packString(name)
      ..packBool(isNullable)
      ..packListLength(typeArguments.length);
    for (var typeArg in typeArguments) {
      typeArg.pack(packer);
    }
  }

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

/// This must be assigned by an implementation.
late ReflectTypeResponse Function(ReflectTypeRequest request) reflectType;

/// This must be assigned by an implementation.
late GetDeclarationResponse Function(GetDeclarationRequest request)
    getDeclaration;
