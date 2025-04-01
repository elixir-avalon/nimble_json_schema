defmodule NimbleJsonSchemaTest do
  use ExUnit.Case
  doctest NimbleJsonSchema

  describe "to_json_schema/1" do
    test "converts basic types correctly" do
      schema = [
        string_field: [type: :string, required: true],
        integer_field: [type: :integer, default: 42],
        float_field: [type: :float],
        boolean_field: [type: :boolean, default: false],
        atom_field: [type: :atom]
      ]

      json_schema = NimbleJsonSchema.to_json_schema(schema)

      assert json_schema["type"] == "object"
      assert json_schema["required"] == ["string_field"]
      assert json_schema["properties"]["string_field"]["type"] == "string"
      assert json_schema["properties"]["integer_field"]["type"] == "integer"
      assert json_schema["properties"]["integer_field"]["default"] == 42
      assert json_schema["properties"]["float_field"]["type"] == "number"
      assert json_schema["properties"]["boolean_field"]["type"] == "boolean"
      assert json_schema["properties"]["boolean_field"]["default"] == false
      assert json_schema["properties"]["atom_field"]["type"] == "string"
    end

    test "handles nested structures" do
      schema = [
        user: [
          type: :keyword_list,
          required: true,
          keys: [
            name: [type: :string, required: true],
            age: [type: :integer]
          ]
        ]
      ]

      json_schema = NimbleJsonSchema.to_json_schema(schema)

      assert json_schema["required"] == ["user"]
      assert json_schema["properties"]["user"]["type"] == "object"
      assert json_schema["properties"]["user"]["required"] == ["name"]
      assert json_schema["properties"]["user"]["properties"]["name"]["type"] == "string"
      assert json_schema["properties"]["user"]["properties"]["age"]["type"] == "integer"
    end

    test "handles list types" do
      schema = [
        tags: [type: {:list, :string}],
        scores: [type: {:list, :integer}]
      ]

      json_schema = NimbleJsonSchema.to_json_schema(schema)

      assert json_schema["properties"]["tags"]["type"] == "array"
      assert json_schema["properties"]["tags"]["items"]["type"] == "string"
      assert json_schema["properties"]["scores"]["type"] == "array"
      assert json_schema["properties"]["scores"]["items"]["type"] == "integer"
    end

    test "handles enum types" do
      schema = [
        status: [type: {:in, [:active, :inactive, :pending]}]
      ]

      json_schema = NimbleJsonSchema.to_json_schema(schema)

      assert json_schema["properties"]["status"]["enum"] == [:active, :inactive, :pending]
    end
  end

  describe "to_function_spec/3" do
    test "creates a valid function spec" do
      schema = [
        name: [type: :string, required: true, doc: "The user's name"],
        age: [type: :integer, default: 30, doc: "The user's age"]
      ]

      function_spec =
        NimbleJsonSchema.to_function_spec("create_user", "Create a new user", schema)

      assert function_spec["name"] == "create_user"
      assert function_spec["description"] == "Create a new user"
      assert function_spec["parameters"]["type"] == "object"
      assert function_spec["parameters"]["required"] == ["name"]
      assert function_spec["parameters"]["properties"]["name"]["type"] == "string"
      assert function_spec["parameters"]["properties"]["name"]["description"] == "The user's name"
      assert function_spec["parameters"]["properties"]["age"]["type"] == "integer"
      assert function_spec["parameters"]["properties"]["age"]["default"] == 30
      assert function_spec["parameters"]["properties"]["age"]["description"] == "The user's age"
    end
  end

  describe "transform_json/2" do
    test "transforms basic response correctly" do
      schema = [
        name: [type: :string, required: true],
        age: [type: :integer, default: 30]
      ]

      json_response = %{
        "name" => "John Doe",
        "age" => 35
      }

      {:ok, transformed} = NimbleJsonSchema.transform_json(json_response, schema)

      assert transformed[:name] == "John Doe"
      assert transformed[:age] == 35
    end

    test "handles nested structures" do
      schema = [
        user: [
          type: :keyword_list,
          required: true,
          keys: [
            name: [type: :string, required: true],
            address: [
              type: :keyword_list,
              keys: [
                street: [type: :string],
                city: [type: :string]
              ]
            ]
          ]
        ]
      ]

      json_response = %{
        "user" => %{
          "name" => "John Doe",
          "address" => %{
            "street" => "123 Main St",
            "city" => "Anytown"
          }
        }
      }

      {:ok, transformed} = NimbleJsonSchema.transform_json(json_response, schema)

      assert transformed[:user][:name] == "John Doe"
      assert transformed[:user][:address][:street] == "123 Main St"
      assert transformed[:user][:address][:city] == "Anytown"
    end

    test "handles lists of objects" do
      schema = [
        users: [
          type: {:list, :keyword_list},
          keys: [
            name: [type: :string, required: true],
            age: [type: :integer]
          ]
        ]
      ]

      json_response = %{
        "users" => [
          %{"name" => "John", "age" => 30},
          %{"name" => "Jane", "age" => 25}
        ]
      }

      {:ok, transformed} = NimbleJsonSchema.transform_json(json_response, schema)

      assert length(transformed[:users]) == 2
      assert Enum.at(transformed[:users], 0)[:name] == "John"
      assert Enum.at(transformed[:users], 0)[:age] == 30
      assert Enum.at(transformed[:users], 1)[:name] == "Jane"
      assert Enum.at(transformed[:users], 1)[:age] == 25
    end

    test "handles missing required fields" do
      schema = [
        name: [type: :string, required: true],
        age: [type: :integer]
      ]

      json_response = %{
        "age" => 35
      }

      assert {:error, error} = NimbleJsonSchema.transform_json(json_response, schema)
      assert error =~ "Required key name not found"
    end

    test "uses default values for missing optional fields" do
      schema = [
        name: [type: :string, required: true],
        age: [type: :integer, default: 30]
      ]

      json_response = %{
        "name" => "John Doe"
      }

      {:ok, transformed} = NimbleJsonSchema.transform_json(json_response, schema)

      assert transformed[:name] == "John Doe"
      assert transformed[:age] == 30
    end

    test "converts string to atom for atom type" do
      schema = [
        status: [type: :atom]
      ]

      json_response = %{
        "status" => "active"
      }

      {:ok, transformed} = NimbleJsonSchema.transform_json(json_response, schema)

      assert transformed[:status] == :active
    end
  end

  describe "transform_json/2 can be validated by NimbleOptions" do
    test "basic response can be validated by NimbleOptions" do
      schema = [
        name: [type: :string, required: true],
        age: [type: :integer, default: 30]
      ]

      json_response = %{
        "name" => "John Doe",
        "age" => 35
      }

      {:ok, transformed} = NimbleJsonSchema.transform_json(json_response, schema)
      assert {:ok, validated} = NimbleOptions.validate(transformed, schema)
      assert validated[:name] == "John Doe"
      assert validated[:age] == 35
    end

    test "nested structures can be validated by NimbleOptions" do
      schema = [
        user: [
          type: :keyword_list,
          required: true,
          keys: [
            name: [type: :string, required: true],
            address: [
              type: :keyword_list,
              keys: [
                street: [type: :string],
                city: [type: :string]
              ]
            ]
          ]
        ]
      ]

      json_response = %{
        "user" => %{
          "name" => "John Doe",
          "address" => %{
            "street" => "123 Main St",
            "city" => "Anytown"
          }
        }
      }

      {:ok, transformed} = NimbleJsonSchema.transform_json(json_response, schema)
      assert {:ok, validated} = NimbleOptions.validate(transformed, schema)
      assert validated[:user][:name] == "John Doe"
      assert validated[:user][:address][:street] == "123 Main St"
    end

    test "validation fails with appropriate error for invalid data" do
      schema = [
        name: [type: :string, required: true],
        age: [type: :pos_integer]
      ]

      json_response = %{
        "name" => "John Doe",
        # Invalid: negative number for pos_integer
        "age" => -5
      }

      {:ok, transformed} = NimbleJsonSchema.transform_json(json_response, schema)
      assert {:error, error} = NimbleOptions.validate(transformed, schema)
      assert Exception.message(error) =~ "invalid value for :age option"
    end

    test "validation with enum types" do
      schema = [
        status: [type: {:in, [:active, :inactive, :pending]}]
      ]

      # Valid status as string that gets converted to atom
      json_response = %{"status" => "active"}
      {:ok, transformed} = NimbleJsonSchema.transform_json(json_response, schema)

      # Our transform_json converts "active" to :active
      assert transformed[:status] == :active
      assert {:ok, validated} = NimbleOptions.validate(transformed, schema)
      assert validated[:status] == :active

      # Invalid status
      json_response2 = %{"status" => "unknown"}
      {:ok, transformed2} = NimbleJsonSchema.transform_json(json_response2, schema)
      assert {:error, error} = NimbleOptions.validate(transformed2, schema)
      assert Exception.message(error) =~ "expected one of [:active, :inactive, :pending]"
    end

    test "validation with custom types" do
      defmodule EmailValidator do
        def validate(email) do
          if String.contains?(email, "@") do
            {:ok, email}
          else
            {:error, "invalid email format"}
          end
        end
      end

      schema = [
        email: [
          type: {:custom, EmailValidator, :validate, []},
          doc: "Valid email address"
        ]
      ]

      # Valid email
      json_response1 = %{"email" => "user@example.com"}
      {:ok, transformed1} = NimbleJsonSchema.transform_json(json_response1, schema)
      assert {:ok, validated1} = NimbleOptions.validate(transformed1, schema)
      assert validated1[:email] == "user@example.com"

      # Invalid email
      json_response2 = %{"email" => "invalid-email"}
      {:ok, transformed2} = NimbleJsonSchema.transform_json(json_response2, schema)
      assert {:error, error} = NimbleOptions.validate(transformed2, schema)
      assert Exception.message(error) =~ "invalid email format"
    end

    test "lists of objects can be validated by NimbleOptions" do
      schema = [
        users: [
          type:
            {:list,
             {:keyword_list,
              [
                name: [type: :string, required: true],
                age: [type: :integer]
              ]}}
        ]
      ]

      json_response = %{
        "users" => [
          %{"name" => "John", "age" => 30},
          %{"name" => "Jane", "age" => 25}
        ]
      }

      {:ok, transformed} = NimbleJsonSchema.transform_json(json_response, schema)
      assert {:ok, validated} = NimbleOptions.validate(transformed, schema)

      users = validated[:users]
      assert length(users) == 2

      first_user = Enum.at(users, 0)
      # Use keyword list access syntax
      assert first_user[:name] == "John"
      assert first_user[:age] == 30

      second_user = Enum.at(users, 1)
      assert second_user[:name] == "Jane"
      assert second_user[:age] == 25
    end
  end

  describe "edge cases for to_json_schema/1" do
    test "handles empty schema" do
      schema = []
      json_schema = NimbleJsonSchema.to_json_schema(schema)

      assert json_schema["type"] == "object"
      assert json_schema["properties"] == %{}
      refute Map.has_key?(json_schema, "required")
    end

    test "handles complex nested structures" do
      schema = [
        metadata: [
          type: :keyword_list,
          keys: [
            tags: [
              type: {:list, :string}
            ],
            nested: [
              type: :keyword_list,
              keys: [
                deep: [
                  type: :keyword_list,
                  keys: [
                    value: [type: :integer]
                  ]
                ]
              ]
            ]
          ]
        ]
      ]

      json_schema = NimbleJsonSchema.to_json_schema(schema)

      assert get_in(json_schema, ["properties", "metadata", "type"]) == "object"

      assert get_in(json_schema, ["properties", "metadata", "properties", "tags", "type"]) ==
               "array"

      assert get_in(json_schema, ["properties", "metadata", "properties", "nested", "type"]) ==
               "object"

      assert get_in(json_schema, [
               "properties",
               "metadata",
               "properties",
               "nested",
               "properties",
               "deep",
               "type"
             ]) == "object"

      assert get_in(json_schema, [
               "properties",
               "metadata",
               "properties",
               "nested",
               "properties",
               "deep",
               "properties",
               "value",
               "type"
             ]) == "integer"
    end
  end

  describe "edge cases for transform_json/2" do
    test "handles empty response" do
      schema = [
        name: [type: :string, default: "Unknown"],
        age: [type: :integer, default: 0]
      ]

      json_response = %{}

      {:ok, transformed} = NimbleJsonSchema.transform_json(json_response, schema)
      assert transformed[:name] == "Unknown"
      assert transformed[:age] == 0
    end

    test "handles deeply nested structures with defaults" do
      schema = [
        user: [
          type: :keyword_list,
          keys: [
            profile: [
              type: :keyword_list,
              keys: [
                preferences: [
                  type: :keyword_list,
                  default: [theme: "light", notifications: true],
                  keys: [
                    theme: [type: :string],
                    notifications: [type: :boolean]
                  ]
                ]
              ]
            ]
          ]
        ]
      ]

      # Partial response with missing nested data
      json_response = %{
        "user" => %{
          "profile" => %{}
        }
      }

      {:ok, transformed} = NimbleJsonSchema.transform_json(json_response, schema)
      assert transformed[:user][:profile][:preferences][:theme] == "light"
      assert transformed[:user][:profile][:preferences][:notifications] == true
    end
  end

  describe "additional integration tests" do
    test "full validation pipeline with complex schema" do
      schema = [
        user: [
          type: :keyword_list,
          required: true,
          keys: [
            name: [type: :string, required: true],
            roles: [
              type: {:list, {:in, [:admin, :user, :guest]}},
              default: [:user]
            ],
            settings: [
              type: :keyword_list,
              keys: [
                theme: [type: {:in, [:light, :dark]}, default: :light],
                notifications: [type: :boolean, default: true]
              ]
            ]
          ]
        ]
      ]

      json_response = %{
        "user" => %{
          "name" => "Test User",
          "roles" => ["admin", "user"],
          "settings" => %{
            "theme" => "dark"
          }
        }
      }

      {:ok, transformed} = NimbleJsonSchema.transform_json(json_response, schema)
      assert {:ok, validated} = NimbleOptions.validate(transformed, schema)

      assert validated[:user][:name] == "Test User"
      assert validated[:user][:roles] == [:admin, :user]
      assert validated[:user][:settings][:theme] == :dark
      assert validated[:user][:settings][:notifications] == true
    end
  end

  describe "to_json_schema/1 with map types" do
    test "handles basic map type" do
      schema = [
        settings: [
          type: :map,
          keys: [
            theme: [type: :string],
            notifications: [type: :boolean]
          ]
        ]
      ]

      json_schema = NimbleJsonSchema.to_json_schema(schema)

      assert json_schema["properties"]["settings"]["type"] == "object"
      assert json_schema["properties"]["settings"]["properties"]["theme"]["type"] == "string"

      assert json_schema["properties"]["settings"]["properties"]["notifications"]["type"] ==
               "boolean"
    end

    test "handles complex map type" do
      schema = [
        metadata: [
          type: {:map, :atom, :string}
        ]
      ]

      json_schema = NimbleJsonSchema.to_json_schema(schema)

      assert json_schema["properties"]["metadata"]["type"] == "object"
    end
  end

  describe "transform_json/2 with map types" do
    test "transforms basic map correctly" do
      schema = [
        settings: [
          type: :map,
          keys: [
            theme: [type: :string],
            notifications: [type: :boolean]
          ]
        ]
      ]

      json_response = %{
        "settings" => %{
          "theme" => "dark",
          "notifications" => true
        }
      }

      {:ok, transformed} = NimbleJsonSchema.transform_json(json_response, schema)

      assert is_map(transformed[:settings])
      assert transformed[:settings][:theme] == "dark"
      assert transformed[:settings][:notifications] == true
    end

    test "transforms complex map correctly" do
      schema = [
        metadata: [
          type: {:map, :atom, :string}
        ]
      ]

      json_response = %{
        "metadata" => %{
          "key1" => "value1",
          "key2" => "value2"
        }
      }

      {:ok, transformed} = NimbleJsonSchema.transform_json(json_response, schema)

      assert is_map(transformed[:metadata])
      assert transformed[:metadata][:key1] == "value1"
      assert transformed[:metadata][:key2] == "value2"
    end

    test "applies default values to maps" do
      schema = [
        settings: [
          type: :map,
          keys: [
            theme: [type: :string, default: "light"],
            notifications: [type: :boolean, default: false]
          ]
        ]
      ]

      json_response = %{
        "settings" => %{
          "theme" => "dark"
        }
      }

      {:ok, transformed} = NimbleJsonSchema.transform_json(json_response, schema)
      assert transformed[:settings][:theme] == "dark"
      assert transformed[:settings][:notifications] == false
    end

    test "validates map with NimbleOptions" do
      schema = [
        settings: [
          type: :map,
          keys: [
            theme: [type: {:in, ["light", "dark"]}, required: true],
            notifications: [type: :boolean, default: false]
          ]
        ]
      ]

      json_response = %{
        "settings" => %{
          "theme" => "dark"
        }
      }

      {:ok, transformed} = NimbleJsonSchema.transform_json(json_response, schema)
      assert {:ok, validated} = NimbleOptions.validate(transformed, schema)

      assert is_map(validated[:settings])
      assert validated[:settings][:theme] == "dark"
      assert validated[:settings][:notifications] == false
    end
  end

  describe "JSON Schema validation with ExJsonSchema" do
    test "generated JSON Schema validates correctly with ExJsonSchema" do
      schema = [
        name: [type: :string, required: true],
        age: [type: :integer, default: 30],
        roles: [type: {:list, {:in, [:admin, :user, :guest]}}, default: [:user]]
      ]

      json_schema = NimbleJsonSchema.to_json_schema(schema)

      # Convert schema to use string keys for ExJsonSchema
      json_schema_with_string_keys =
        json_schema
        |> JSON.encode!()
        |> JSON.decode!()

      # Resolve the schema using ExJsonSchema
      resolved_schema = ExJsonSchema.Schema.resolve(json_schema_with_string_keys)

      # Valid data
      valid_data = %{"name" => "John", "age" => 35, "roles" => ["admin", "user"]}
      assert ExJsonSchema.Validator.valid?(resolved_schema, valid_data)

      # Invalid data - missing required field
      invalid_data1 = %{"age" => 25}
      refute ExJsonSchema.Validator.valid?(resolved_schema, invalid_data1)

      # Invalid data - wrong type
      invalid_data2 = %{"name" => "John", "age" => "thirty"}
      refute ExJsonSchema.Validator.valid?(resolved_schema, invalid_data2)

      # Invalid data - invalid enum value
      invalid_data3 = %{"name" => "John", "roles" => ["superuser"]}
      refute ExJsonSchema.Validator.valid?(resolved_schema, invalid_data3)
    end

    test "generated nested JSON Schema validates correctly" do
      schema = [
        user: [
          type: :keyword_list,
          required: true,
          keys: [
            name: [type: :string, required: true],
            profile: [
              type: :keyword_list,
              keys: [
                bio: [type: :string],
                social: [
                  type: {:list, :string}
                ]
              ]
            ]
          ]
        ]
      ]

      json_schema = NimbleJsonSchema.to_json_schema(schema)

      # Convert schema to use string keys for ExJsonSchema
      json_schema_with_string_keys =
        json_schema
        |> JSON.encode!()
        |> JSON.decode!()

      # Resolve the schema using ExJsonSchema
      resolved_schema = ExJsonSchema.Schema.resolve(json_schema_with_string_keys)

      # Valid data
      valid_data = %{
        "user" => %{
          "name" => "John",
          "profile" => %{
            "bio" => "Developer",
            "social" => ["twitter", "github"]
          }
        }
      }

      assert ExJsonSchema.Validator.valid?(resolved_schema, valid_data)

      # Invalid data - missing required user field
      invalid_data1 = %{}
      refute ExJsonSchema.Validator.valid?(resolved_schema, invalid_data1)

      # Invalid data - missing required name field
      invalid_data2 = %{"user" => %{"profile" => %{"bio" => "Developer"}}}
      refute ExJsonSchema.Validator.valid?(resolved_schema, invalid_data2)

      # Invalid data - wrong type for social
      invalid_data3 = %{
        "user" => %{
          "name" => "John",
          "profile" => %{
            "bio" => "Developer",
            # Should be an array
            "social" => "twitter"
          }
        }
      }

      refute ExJsonSchema.Validator.valid?(resolved_schema, invalid_data3)
    end
  end

  describe "function_spec with ExJsonSchema" do
    test "function spec parameters validate correctly" do
      schema = [
        name: [type: :string, required: true, doc: "The user's name"],
        age: [type: :integer, default: 30, doc: "The user's age"]
      ]

      function_spec =
        NimbleJsonSchema.to_function_spec("create_user", "Create a new user", schema)

      # Extract parameters schema from function spec
      parameters_schema = function_spec["parameters"]

      # Convert schema to use string keys for ExJsonSchema
      parameters_schema_with_string_keys =
        parameters_schema
        |> JSON.encode!()
        |> JSON.decode!()

      # Resolve the schema using ExJsonSchema
      resolved_schema = ExJsonSchema.Schema.resolve(parameters_schema_with_string_keys)

      # Valid data
      valid_data = %{"name" => "John", "age" => 35}
      assert ExJsonSchema.Validator.valid?(resolved_schema, valid_data)

      # Invalid data - missing required field
      invalid_data = %{"age" => 25}
      refute ExJsonSchema.Validator.valid?(resolved_schema, invalid_data)

      # Get validation errors
      {:error, errors} = ExJsonSchema.Validator.validate(resolved_schema, invalid_data)
      assert length(errors) > 0
    end
  end

  describe "end-to-end workflow" do
    test "schema conversion, validation, and transformation" do
      # 1. Define NimbleOptions schema
      nimble_schema = [
        name: [type: :string, required: true],
        active: [type: :boolean, default: false],
        tags: [type: {:list, :string}]
      ]

      # 2. Convert to JSON Schema
      json_schema = NimbleJsonSchema.to_json_schema(nimble_schema)

      # 3. Prepare for ExJsonSchema validation
      json_schema_with_string_keys =
        json_schema
        |> JSON.encode!()
        |> JSON.decode!()

      resolved_schema = ExJsonSchema.Schema.resolve(json_schema_with_string_keys)

      # 4. Mock JSON response
      mock_json_response = %{
        "name" => "Test User",
        "active" => true,
        "tags" => ["test", "user"]
      }

      # 5. Validate with ExJsonSchema
      assert ExJsonSchema.Validator.valid?(resolved_schema, mock_json_response)

      # 6. Transform the response for NimbleOptions validation
      {:ok, transformed} =
        NimbleJsonSchema.transform_json(mock_json_response, nimble_schema)

      # 7. Validate with NimbleOptions
      assert {:ok, validated} = NimbleOptions.validate(transformed, nimble_schema)

      # 8. Verify the data
      assert validated[:name] == "Test User"
      assert validated[:active] == true
      assert validated[:tags] == ["test", "user"]
    end

    test "validation errors are consistent between ExJsonSchema and NimbleOptions" do
      # 1. Define schema with constraints
      nimble_schema = [
        username: [type: :string, required: true],
        age: [type: :pos_integer]
      ]

      # 2. Convert to JSON Schema
      json_schema = NimbleJsonSchema.to_json_schema(nimble_schema)

      # 3. Prepare for ExJsonSchema validation
      json_schema_with_string_keys =
        json_schema
        |> JSON.encode!()
        |> JSON.decode!()

      resolved_schema = ExJsonSchema.Schema.resolve(json_schema_with_string_keys)

      # 4. Invalid JSON response - negative age for pos_integer
      invalid_json_response = %{
        "username" => "testuser",
        "age" => -5
      }

      # 5. Validate with ExJsonSchema - should fail
      refute ExJsonSchema.Validator.valid?(resolved_schema, invalid_json_response)

      # 6. Transform the response for NimbleOptions validation
      {:ok, transformed} =
        NimbleJsonSchema.transform_json(invalid_json_response, nimble_schema)

      # 7. Validate with NimbleOptions - should also fail
      assert {:error, _} = NimbleOptions.validate(transformed, nimble_schema)
    end
  end

  describe "schema fragments with ExJsonSchema" do
    test "validate against schema fragments" do
      schema = [
        user: [
          type: :keyword_list,
          keys: [
            name: [type: :string, required: true],
            email: [type: :string, format: "email"]
          ]
        ],
        settings: [
          type: :keyword_list,
          keys: [
            theme: [type: {:in, ["light", "dark"]}],
            notifications: [type: :boolean]
          ]
        ]
      ]

      json_schema = NimbleJsonSchema.to_json_schema(schema)

      # Convert schema to use string keys for ExJsonSchema
      json_schema_with_string_keys =
        json_schema
        |> JSON.encode!()
        |> JSON.decode!()

      resolved_schema = ExJsonSchema.Schema.resolve(json_schema_with_string_keys)

      # Get the settings fragment
      settings_fragment =
        ExJsonSchema.Schema.get_fragment!(
          resolved_schema,
          "#/properties/settings"
        )

      # Valid settings data
      valid_settings = %{"theme" => "dark", "notifications" => true}

      assert ExJsonSchema.Validator.valid_fragment?(
               resolved_schema,
               settings_fragment,
               valid_settings
             )

      # Invalid settings data
      invalid_settings = %{"theme" => "blue", "notifications" => true}

      refute ExJsonSchema.Validator.valid_fragment?(
               resolved_schema,
               settings_fragment,
               invalid_settings
             )
    end
  end
end
