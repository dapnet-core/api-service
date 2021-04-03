defmodule Dapnet.User.Schema do
  def user_schema do
    %{
      "type" => "object",
      "additionalProperties" => true,
      "required" => [
        "_id",
        "email",
        "enabled",
        "roles"
      ],
      "properties" => %{
        "id" => %{
          "type" => "string",
          "pattern" => "^[a-z0-9]+$"
        },
        "enabled" => %{"type" => "boolean"},
        "email" => %{
          "type" => "string",
          "format" => "email"
        },
        "roles" => %{
          "type" => "array",
          "items" => %{"type" => "string"},
          "uniqueItems": true
        }
      }
    }
    |> ExJsonSchema.Schema.resolve()
  end
end