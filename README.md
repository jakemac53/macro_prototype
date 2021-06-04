# Description

This is a basic prototype for macros using package:build.

## Setup

To use it you will need to build a custom SDK that allows patch files, which
exists here https://github.com/jakemac53/sdk/tree/allow-arbitrary-patches.

## Writing a macro

To create a new macro see the example one at `lib/src/json.dart`. You will need
to update the `createBuilder` method in `macro_builder.dart`, to pass in your
new macro to the constructor.

Note that only Phase 3 macros are supported, at least for now.

## Running macros

You will use the build_runner package to run builds, which you can run with the
`pub run build_runner build` command. There is also a `watch` command you may
want to use to get fast rebuilds.

If you want to build and run an app in a single command, you can use the `run`
command: `pub run build_runner run example/main.dart`.
