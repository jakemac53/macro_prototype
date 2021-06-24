## Description

This is a basic prototype for 3 phase macros using package:build.

The general idea is that macros run in 3 different phases, and each phase has
different capabilities available to it in terms of both introspection and code
generation power.

Macros are applied as annotations on declarations. They are currently supported
on classes, methods, and fields.

This phases approach allows us to provide consistent, correct results for the
introspection apis that are available, while simultaneously providing a lot
of power in the form of adding entirely new declarations to the program.

## API Docs

The api docs can be seen [here](https://jakemac53.github.io/macro_prototype/doc/api/index.html).

These are generated and published manually so they may become a bit stale, you
can regenerate them by checking out the `gh-pages` branch, running `dartdoc`
from the root of the repo, and sending a pull request to that branch.

## Evaluation Guidelines

This prototype **is not** intended to reflect the final dev experience.
Specifically, the IDE and codegen experience you see here is not a
reflection of the final expected product. The actual feature would be built
into the compilation pipelines you already use, and you would not see any
generated files in your source directory.

We would like feedback focused on any other area though, such as:

- Does this provide enough functionality for you to do everything you want to?
- General feedback on the macro apis (anything exported by
  `lib/definition.dart`).
- General feedback on the multi-phased approach.
- Any other feedback unrelated to build_runner or the specific code generation
  process used in this prototype.

Note that if  you do implement some macros, we would love for you to contribute
them to the repo so we have more concrete examples of the use cases!

## Intro to the Macro interfaces

Each type of macro has it's own interface, each of which have a single method
that you must implement. These methods each take two arguments, the first
argument is the object you use to introspect on the object that was annotated
with the macro, and the second argument is a builder object used to modify the
program.

For example, lets take a look at the `ClassDeclarationMacro` interface:

```dart
/// The interface for [DeclarationMacro]s that can be applied to classes.
abstract class ClassDeclarationMacro implements DeclarationMacro {
  void visitClassDeclaration(
      ClassDeclaration declaration, ClassDeclarationBuilder builder);
}
```

This macro is given a `ClassDeclaration` object as the first argument, which
gives you all the reflective information available for a class, in the
"declaration" phase (phase 2).

The second argument is a `ClassDeclarationBuilder`, which has an
`addToClass(Declaration declaration)` method you can use to add new
declarations to the class. A `ClassDeclarationBuilder` is also a
`DeclarationBuilder`, which gives you the ability to add top level declarations
with the `addToLibrary(Declaration declaration)` method.

### Implementing Multiple Macro Interfaces

A single macro class is allowed to implement multiple macro interfaces, which
allows it to run in several phases. As an example of this you can look at the
`example/macros/json.dart` macro, which implements three different macro
interfaces. First, is the `ClassDeclarationMacro`, which it uses to define the
interface only of the `fromJson` constructor and `toJson` methods.

It then also implements the `ConstructorDefinitionMacro` and
`MethodDefinitionMacro` interfaces which it uses to fill in those declarations
with the full implementations.

Note that a macro can provide a full definition in the declaration phase, but
the json macro needs more reflective information than is available to it in
that phase, so it waits until the later phase where it can fully introspect
on the program to fill in the implementations.

### Phase 1 - Type Macros

These macros have almost no introspection capability, but are allowed to
introduce entirely new classes to the application.

To make a macro run in this phase you should implement either `ClassTypeMacro`,
`FieldTypeMacro`, or `MethodTypeMacro`, depending on which type of declaration
your macro supports running on.

### Phase 2 - Declaration Macros

These macros can introspect on the declaration they annotate, but cannot
recursively introspect on the types referenced in those declarations. They are
however allowed to ask questions about type relationships for any types they
see, through the `isSubtypeOf` api.

These macros are allowed to introduce new public declarations to classes, as
well as the current library, but not new types.

To make a macro run in this phase you should implement either
`ClassDeclarationMacro`, `FieldDeclarationMacro`, or `MethodDeclarationMacro`,
depending on which type of declaration your macro supports running on.

### Phase 3 - Definition Macros

These macros can introspect fully on the declaration they annotate, including
recursively introspecting on the types referenced in those declarations.

In exchange for this introspection power, these macros are only allowed to
implement existing declarations. No new declarations can be added in this phase,
so the static shape of the program is fully complete before these macros run.

To make a macro run in this phase you should implement either
`ClassDefinitionMacro`, `FieldDefinitionMacro`, or `MethodDefinitionMacro`,
depending on which type of declaration your macro supports running on.

## Example Macros, Wiring Up a New Macro

### VM example

You can see some examples under `example/macros`.

Once you create a macro you will need to add it to all the phases in which it
should run, see the `typesBuilder`, `declarationsBuilder`, and
`definitionsBuilder` methods in `example/builders.dart`, and pass in your new
macro to the corresponding constructor for the phase in which it should run.

### Flutter example

You can see flutter examples under `flutter_example/macros`.

Once you create a macro you will need to add it to all the phases in which it
should run, see the `typesBuilder`, `declarationsBuilder`, and
`definitionsBuilder` methods in `flutter_example/lib/builders.dart`, and pass
in your new macro to the corresponding constructor for the phase in which it
should run.

## Using a Macro

For this prototype you need to create your example files that use your macros
with the extension `.gen.dart`. We will run codegen on only those files,
applying the macros and generating a file for the output at each phase.

The final phase will create a regular `.dart` file which is what you should
import. If you want to import other files which also use codegen, you should do
so by importing the `.gen.dart` files, this will ensure they are visible to the
build of your library (and only the appropriate info should be available).

## Running macros

You will use the build_runner package to run builds, which you can run with the
`pub run build_runner build` (or `flutter pub run build_runner build`) command.
There is also a `watch` command you may want to use to get fast rebuilds.

For vm apps if you want to build and run an app in a single command, you can
use the `run` command: `pub run build_runner run example/main.dart`.

For flutter apps you will need to run build_runner separately, and then launch
the flutter app as normal.
