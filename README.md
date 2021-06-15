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

### Phase 1 - Type Macros

These macros have almost no introspection capability, but are allowed to
introduce entirely new classes to the application.

To make a macro run in this phase you should implement either `ClassTypeMacro`,
`FieldTypeMacro`, or `MethodTypeMacro`, depending on which type of declaration
your macro supports running on.

The object you recieve in the `type` method that you implement will have an
`addTypeToLibary(Code declaration)` method, which you can use to add new types
to the program.

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

Once you create a macro (under `flutter_example/lib/macros`) you will need to
also create a special annotation class for it in
`flutter_example/lib/annotations.dart`. This needs to be a separate class in
order to avoid imports of `dart:mirrors` in the flutter application.

Next you need to add your macro to all the phases in which it should run, see
the `typesBuilder`, `declarationsBuilder`, and `definitionsBuilder` methods in
`flutter_example/lib/builders.dart`. You should add a map entry where the key
is the annotation for the macro, and the value is the macro that should be
applied when that annotation is present.

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
