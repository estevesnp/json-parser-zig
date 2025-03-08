# `json-parser-zig`

A simple JSON parser in Zig

## Installation

1. Add to your `build.zig.zon` with the following command:

```bash
zig fetch --save git+https://github.com/estevesnp/json-parser-zig#main
```

2. Add the following to your `build.zig`:

```zig
b.installArtifact(exe);

const json = b.dependency("json_parser_zig", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("json", json.module("json_parser_zig"));
```

## TODO

- ParseResult tag union with ParseError that has position context
- Error type for serializer and deserializer
- Add compile time checks where possible
