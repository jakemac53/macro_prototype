# Description

This is a basic prototype for 3 phase macros using package:build.

## Writing a macro

To create a new macro see the examples under `example/macros`. Once you create
a builder you will need to add it to all the phases in which it should run, see
the `typesBuilder`, `declarationsBuilder`, and `definitionsBuilder` methods in
`example/builders.dart`, and pass in your new macro to the corresponding
constructor for the phase in which it should run.

## Creating an example

For this prototype you need to create your example files that use your macros
with the extension `.gen.dart`. We will run codegen on only those files,
applying the macros and generating a file for the output at each phase.

The final phase will create a regular `.dart` file which is what you should
import. If you want to import other files which also use codegen, you should do
so by importing the `.gen.dart` files, this will ensure they are visible to the
build of your library (and only the appropriate info should be available).

## Running macros

You will use the build_runner package to run builds, which you can run with the
`pub run build_runner build` command. There is also a `watch` command you may
want to use to get fast rebuilds.

If you want to build and run an app in a single command, you can use the `run`
command: `pub run build_runner run example/main.dart`.
