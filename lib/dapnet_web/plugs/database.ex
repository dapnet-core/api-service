defmodule DapnetWeb.Plugs.Database do
  defmacro __using__(opts) do
    quote do
      alias CouchDB.Database

      @db_name unquote(opts[:name])

      def db() do
        Dapnet.CouchDB.db(@db_name)
      end

      def db_get(id) do
        result = Database.get(db(), id)

        with {:ok, result} <- result do
          Jason.decode(result)
        end
      end

      def db_view(name, options \\ %{}) do
        result = Database.view(db(), @db_name, name, options)

        with {:ok, result} <- result do
          Jason.decode(result)
        end
      end

      def db_list(name, view, options \\ %{}) do
        result = Database.list(db(), @db_name, name, view, options)

        with {:ok, result} <- result do
          Jason.decode(result)
        end
      end
    end
  end
end