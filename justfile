#!/usr/bin/env just --justfile

test:
    fvm dart test

get:
    rm -f rpc_example/pubspec.lock
    rm -rf rpc_example/.dart_tool

    rm -f rpc_dart_transports/pubspec.lock
    rm -rf rpc_dart_transports/.dart_tool

    rm -f rpc_dart/pubspec.lock
    rm -rf rpc_dart/.dart_tool

    rm -rf .dart_tool

    fvm dart pub global run packo pubget -r

gen:
    rm -f rpc_example/pubspec.lock
    rm -rf rpc_example/.dart_tool

    rm -f rpc_dart_transports/pubspec.lock
    rm -rf rpc_dart_transports/.dart_tool

    rm -f rpc_dart/pubspec.lock
    rm -rf rpc_dart/.dart_tool

    rm -rf .dart_tool

    fvm dart pub global run packo runner -r

compile:
    cd rpc_example && rm pubspec.lock
    cd rpc_example && fvm dart pub get
    cd rpc_example && fvm dart compile exe bin/main.dart -o bin/examples
    cd rpc_example && chmod +x bin/examples

demo_server:
    cd rpc_example/bin/integration && fvm dart run demo_server.dart

demo_client:
    cd rpc_example/bin/integration && fvm dart run demo_client.dart

demo_diagnostic:
    cd rpc_example/bin/integration && fvm dart run diagnostic_service.dart