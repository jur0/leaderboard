defmodule Leaderboard do
  @moduledoc """
  Leader board (rank table) implementation based on ETS tables.
  """

  use GenServer

  @typedoc """
  The name of (key) ETS table
  """
  @type table_name :: atom

  @typedoc """
  Options used by the `start*` functions
  """
  @type options :: GenServer.options

  @typedoc """
  Return values of `start*` functions
  """
  @type on_start :: GenServer.on_start

  @typedoc """
  Score of a given key
  """
  @type score :: Leaderboard.Table.score

  @typedoc """
  Key associated with a score
  """
  @type key :: Leaderboard.Table.key

  @typedoc """
  Score and key together
  """
  @type record :: Leaderboard.Table.record

  @typedoc """
  Match specification
  """
  @type match_spec :: Leaderboard.Table.match_spec

  @typedoc """
  Order of returned records
  """
  @type order :: Leaderboard.Table.order

  @typedoc """
  The max number of records to return (or all of them)
  """
  @type limit :: Leaderboard.Table.limit

  @doc """
  Starts `GenServer` process without links. The process is the owner of
  ETS tables (`score_table` and `value_table`).
  """
  @spec start(table_name, options) :: on_start
  def start(table_name, options \\ []) do
    GenServer.start(__MODULE__, [table_name], options)
  end

  @doc """
  Starts `GenServer` process with link to the current process. The process
  is the owner of ETS tables (`score_table` and `value_table`).
  """
  @spec start_link(table_name, options) :: on_start
  def start_link(table_name, options \\ []) do
    GenServer.start_link(__MODULE__, [table_name], options)
  end

  @doc """
  Deletes a record based on the `key`.
  """
  @spec delete(table_name, key) :: boolean
  def delete(table_name, key) do
    server = Leaderboard.Table.server_pid(table_name)
    GenServer.call(server, {:delete, key})
  end

  @doc """
  Inserts a new `record` or updates the `score` of an existing `record`.
  """
  @spec insert(table_name, score, key) :: :ok
  def insert(table_name, score, key) do
    server = Leaderboard.Table.server_pid(table_name)
    GenServer.call(server, {:insert, score, key})
  end

  @doc """
  Returns the `score` associated with a `key`.
  """
  @spec lookup(table_name, key) :: score | nil
  def lookup(table_name, key) do
    Leaderboard.Table.lookup(table_name, key)
  end

  @doc """
  Returns all the values as defined in `match_spec`. Note that the returned
  values don't have to be `record`s (`{score, key}`). The values are matched
  using the `match_spec` and ordered in specified `order`.
  """
  @spec match(table_name, match_spec, order) :: [term]
  def match(table_name, match_spec, order) do
    Leaderboard.Table.match(table_name, match_spec, order, :all)
  end

  @doc """
  Behaves the same as `match/3`, but also has `limit` that defines the max
  number of returned values.
  """
  @spec match(table_name, match_spec, order, limit) :: [term]
  def match(table_name, match_spec, order, limit) do
    Leaderboard.Table.match(table_name, match_spec, order, limit)
  end

  @doc """
  Returns all the `record`s ordered in specified `order`.
  """
  @spec select(table_name, order) :: [record]
  def select(table_name, order) do
    Leaderboard.Table.select(table_name, order, :all)
  end

  @doc """
  Behaves the same as `select/2`, but also has `limit` that defines the max
  number of returned `record`s.
  """
  @spec select(table_name, order, limit) :: [record]
  def select(table_name, order, limit) do
    Leaderboard.Table.select(table_name, order, limit)
  end

  @doc """
  Returns the number of `record`s in the table.
  """
  @spec size(table_name) :: non_neg_integer
  def size(table_name) do
    Leaderboard.Table.size(table_name)
  end

  def init([table_name]) do
    score_table = Leaderboard.Table.init_score_table(table_name)
    key_table = Leaderboard.Table.init_key_table(table_name, self())
    {:ok, %{score_table: score_table, key_table: key_table}}
  end

  def handle_call({:insert, score, key}, _from,
      %{score_table: score_table, key_table: key_table} = state) do
    Leaderboard.Table.delete(key, score_table, key_table)
    Leaderboard.Table.insert(score, key, score_table, key_table)
    {:reply, :ok, state}
  end
  def handle_call({:delete, key}, _from,
      %{score_table: score_table, key_table: key_table} = state) do
    Leaderboard.Table.delete(key, score_table, key_table)
    {:reply, :ok, state}
  end
end

defmodule Leaderboard.Table do
  @moduledoc false

  @server_key :"$server_pid"
  @match_spec_all [{{:"$1"}, [], [:"$1"]}]

  @type score_table :: atom

  @type key_table :: atom

  @type score :: term

  @type key :: term

  @type record :: {score, key}

  @type match_spec :: :ets.match_spec

  @type order :: :ascend | :descend

  @type limit :: pos_integer | :all

  @spec init_score_table(key_table) :: score_table
  def init_score_table(key_table) do
    table_name = score_table_name(key_table)
    :ets.new(table_name, [:ordered_set, :protected, :named_table,
                          read_concurrency: true])
  end

  @spec init_key_table(key_table, pid) :: key_table
  def init_key_table(key_table, server_pid) do
    :ets.new(key_table, [:set, :protected, :named_table,
                           read_concurrency: true])
    :ets.insert(key_table, {@server_key, server_pid})
    key_table
  end

  @spec server_pid(key_table) :: pid
  def server_pid(key_table) do
    [{@server_key, pid}] = :ets.lookup(key_table, @server_key)
    pid
  end

  @spec delete(key, score_table, key_table) :: boolean
  def delete(key, score_table, key_table) do
    case :ets.lookup(key_table, key) do
      [{^key, score}] ->
          :ets.delete(key_table, key)
          :ets.delete(score_table, {score, key})
          true
      [] ->
          false
    end
  end

  @spec insert(term, term, score_table, key_table) :: true
  def insert(score, key, score_table, key_table) do
    # Score table has only key key which is {score, key}. It has type
    # :ordered_set, so all keys must be unique. If just score was in the
    # key there couldn't be 2 and more records with the same score.
    :ets.insert(score_table, {{score, key}})
    :ets.insert(key_table, {key, score})
  end

  @spec lookup(key_table, term) :: term | nil
  def lookup(key_table, key) do
    case :ets.lookup(key_table, key) do
      [{^key, score}] -> score
      [] -> nil
    end
  end

  @spec match(key_table, match_spec, order, limit) :: [term]
  def match(key_table, match_spec, order, limit) do
    score_table = score_table_name(key_table)
    perform_match(score_table, match_spec, order, limit)
  end

  @spec select(key_table, order, limit) :: [term]
  def select(key_table, order, 1) do
    score_table = score_table_name(key_table)
    perform_single_select(score_table, order)
  end
  def select(key_table, order, limit) do
    match(key_table, @match_spec_all, order, limit)
  end

  @spec size(key_table) :: non_neg_integer
  def size(key_table) do
    :ets.info(key_table, :size) - 1
  end

  defp score_table_name(key_table) do
    # Append "Score" to key_table
    Module.concat(key_table, "Score")
  end

  defp perform_single_select(table, :descend) do
    table
    |> :ets.last()
    |> single_select_result()
  end
  defp perform_single_select(table, :ascend) do
    table
    |> :ets.first()
    |> single_select_result()
  end

  defp single_select_result({_score, _key} = record), do: [record]
  defp single_select_result(_), do: []

  defp perform_match(table, match_spec, :descend, :all) do
    table
    |> :ets.select_reverse(match_spec)
    |> match_result()
  end
  defp perform_match(table, match_spec, :descend, limit) do
    table
    |> :ets.select_reverse(match_spec, limit)
    |> match_result()
  end
  defp perform_match(table, match_spec, :ascend, :all) do
    table
    |> :ets.select(match_spec)
    |> match_result()
  end
  defp perform_match(table, match_spec, :ascend, limit) do
    table
    |> :ets.select(match_spec, limit)
    |> match_result()
  end

  defp match_result({records, _cont}), do: records
  defp match_result(records) when is_list(records), do: records
  defp match_result(_), do: []
end
