#!/usr/bin/env just --justfile

test:
    fvm dart test

setup:
    rm -f rpc_example/pubspec.lock
    rm -f rpc_dart_transports/pubspec.lock
    rm -f rpc_dart/pubspec.lock
    fvm dart pub global run packo runner -r

compile:
    cd rpc_example && rm pubspec.lock
    cd rpc_example && fvm dart pub get
    cd rpc_example && fvm dart compile exe bin/main.dart -o bin/examples
    cd rpc_example && chmod +x bin/examples
