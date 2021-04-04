defmodule Dapnet.Subscriber.Schema do
  def subscriber_schema do
    %{
      "type" => "object",
      "additionalProperties" => true,
      "required" => [
        "_id",
        "groups",
        "owners"
      ],
      "properties" => %{
        "id" => %{
          "type" => "string",
          "pattern" => "^[a-z0-9]+$"
        },
        "description" => %{"type" => "string"},
        "groups" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "uniqueItems": true
        },
        "owners" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "uniqueItems": true
        },
        "pagers" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "name" => %{"type" => "string"},
              "type" => %{"type" => "string"},
              "enabled" => %{"type" => "boolean"},
              "ric" => %{"type" => "integer"},
              "function" => %{
                "type" => "integer",
                "minimum" => 0,
                "maximum" => 3
              }
            }
          }
        },
      }
    }
    |> ExJsonSchema.Schema.resolve()
  end
end