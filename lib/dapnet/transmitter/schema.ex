defmodule Dapnet.Transmitter.Schema do
  def transmitter_schema do
    %{
      "type" => "object",
      "additionalProperties" => true,
      "required" => [
        "_id",
        "auth_key",
        "enabled",
        "timeslots",
        "usage",
        "owners"
      ],
      "properties" => %{
        "_id" => %{
          "type" => "string",
          "pattern" => "^[a-z0-9]+$"
        },
        "enabled" => %{"type" => "boolean"},
        "auth_key" => %{"type" => "string"},
        "timeslots" => %{
          "type" => "array",
          "items" => %{"type" => "boolean"},
          "minItems": 16,
          "maxItems": 16
        },
        "power" => %{
          "type" => "integer",
          "minimum" => 0,
          "maximum" => 10000
        },
        "antenna" => %{
          "type" => "object",
          "properties" => %{
            "type" => %{
              "type" => "string",
              "enum" => ["omni", "directional"],
            },
            "gain" => %{"type" => "integer"},
            "direction" => %{
              "type" => "integer",
              "minimum" => 0,
              "maximum" => 360
            },
            "agl" => %{"type" => "integer"}
          }
        },
        "usage" => %{
          "type" => "string",
          "enum" => ["personal", "widerange"],
        },
        "owners" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "uniqueItems": true
        },
        "groups" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "uniqueItems": true
        },
        "emergency_power" => %{
          "type" => "object",
          "properties" => %{
            "available" => %{"type" => "boolean"},
            "infinite" => %{"type" => "boolean"},
            "duration" => %{"type" => "integer"}
          }
        },
        "coordinates" => %{
          "type" => "array",
          "items" => %{"type" => "number"},
          "minItems": 2,
          "maxItems": 2
        },
        "frequency" => %{
          "type" => "number"
        },
        "aprs_broadcast" => %{"type" => "boolean"}
      }
    }
    |> ExJsonSchema.Schema.resolve()
  end
end