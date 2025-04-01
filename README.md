# NimbleJsonSchema

[![Hex.pm](https://img.shields.io/hexpm/v/nimble_json_schema.svg)](https://hex.pm/packages/nimble_json_schema)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/nimble_json_schema)
[![License](https://img.shields.io/hexpm/l/nimble_json_schema.svg)](https://hex.pm/packages/nimble_json_schema)

Seamless bidirectional conversion between NimbleOptions schemas and JSON Schema for Elixir applications.

## Overview

NimbleJsonSchema bridges the gap between Elixir's [NimbleOptions](https://hexdocs.pm/nimble_options/NimbleOptions.html) validation system and [JSON Schema](https://json-schema.org/), providing tools to:

1. **Convert NimbleOptions schemas to JSON Schema** - Useful for structured output validation with LLMs
2. **Convert NimbleOptions schemas to function specifications** - For LLM function calling APIs
3. **Transform raw JSON responses from LLMs** into properly structured data that can be validated by NimbleOptions

This library is particularly valuable when working with Large Language Models (LLMs) like OpenAI's GPT or Anthropic's Claude, allowing you to leverage your existing NimbleOptions schemas for LLM integrations. It is also often easier to programmatically construct a NimbleOptions schema for on-the-fly structured outputs and other fun stuff.

## Installation

This package is currently in prerelease. Add `nimble_json_schema` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:nimble_json_schema, github: "elixir-avalon/nimble_json_schema"}
  ]
end
```

## Usage

### Converting a NimbleOptions schema to JSON Schema

```elixir
schema = [
  name: [type: :string, required: true],
  age: [type: :integer, default: 30],
  roles: [type: {:list, {:in, [:admin, :user, :guest]}}, default: [:user]]
]

json_schema = NimbleJsonSchema.to_json_schema(schema)
```

The resulting JSON Schema can be used with LLM providers that support structured output validation.

### Creating a function specification for LLM function calling

```elixir
schema = [
  name: [type: :string, required: true, doc: "The user's name"],
  age: [type: :integer, default: 30, doc: "The user's age"]
]

function_spec = NimbleJsonSchema.to_function_spec("create_user", "Create a new user", schema)
```

This function spec can be used with LLM providers that support function calling like OpenAI's API.

### Transforming LLM responses for NimbleOptions validation

```elixir
schema = [
  name: [type: :string, required: true],
  active: [type: :boolean, default: false]
]

llm_response = %{"name" => "Alice", "active" => true}

{:ok, transformed} = NimbleJsonSchema.transform_llm_response(llm_response, schema)
{:ok, validated} = NimbleOptions.validate(transformed, schema)
```

## Type Mappings

| NimbleOptions Type      | JSON Schema Type                      |
|-------------------------|---------------------------------------|
| `:string`               | `"string"`                            |
| `:atom`                 | `"string"`                            |
| `:integer`              | `"integer"`                           |
| `:non_neg_integer`      | `"integer"` with `"minimum": 0`       |
| `:pos_integer`          | `"integer"` with `"minimum": 1`       |
| `:float`                | `"number"`                            |
| `:boolean`              | `"boolean"`                           |
| `:keyword_list`         | `"object"` with nested properties     |
| `:map`                  | `"object"` with nested properties     |
| `{:list, subtype}`      | `"array"` with items of subtype       |
| `{:in, values}`         | Object with `"enum"` property         |

## Documentation

For detailed API documentation, please see the [HexDocs](https://hexdocs.pm/nimble_json_schema).

## Development Status

This library is currently in prerelease. The API may change before the 1.0 release.

### Roadmap to 1.0

- [x] Core conversion between NimbleOptions and JSON Schema
- [x] Support for transforming LLM responses
- [x] Support for function specifications
- [ ] Complete test coverage
- [ ] Documentation improvements
- [ ] Additional helper functions for common LLM workflows

## Contributing

Contributions are welcome and appreciated. To contribute:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please make sure to update tests as appropriate and follow Elixir coding standards.

## License

 Copyright 2025 Christopher Grainger

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

## Acknowledgements

- [Dashbit](https://dashbit.co/) for the excellent [NimbleOptions](https://github.com/dashbitco/nimble_options) library (and all the `Nimble*` libs)
- The [JSON Schema](https://json-schema.org/) community for their work on standardizing schema validation
- [Amplified](https://www.amplified.ai/) for supporting this project
