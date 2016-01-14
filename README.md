# Bender
[![DUB](https://img.shields.io/dub/l/vibe-d.svg)]()

Yet another JSON validating and binding framework for Swift. WIP.

This is a tool to firstly check incoming JSON and in the last turn to bind it to arbitrary app model class.

Bender
- does not require your model classes to inherit from any library roots;
- focuses on JSON data describing, not your classes;
- supports mandatory fields checking with error throwing;
- does not require exact field naming or even field existance;
- supports [nested] classes with all JSON natural field types, arrays (including JSON root ones), custom enums with strict checking. Will support wide range of field types shortly, including dates, 'stringified' JSON etc.;
- is quick, does not use introspection or any other blood magic;
- allows you to write your own validator in a couple of dosen lines.

but
- may require a lot of memory in case of big JSON chank: uses NSJSONSerialization under the hood;
- _does not support_ structs as models by design for now.
