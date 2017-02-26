defmodule Leaderboard do
  @moduledoc ~S"""
  The implementation of leaderboard (rank table) based on ETS tables.

  It associates a key with a score and orders these records according to the
  score. The score can be any term.

  The leaderboard provides an API for inserting and deleting records as well
  as functions for reading records in defined order.

  ## Usage

  Once the leaderboard is started using `Leaderboard.start_link/2` with
  a unique name of the table, it can be used to store and read records:

      {:ok, _pid} = Leaderboard.start_link(Leaderboad.Score)
      Leaderboard.insert(Leaderboard.Score, 1, "key1")
      Leaderboard.insert(Leaderboard.Score, 3, "key3")
      Leaderboard.insert(Leaderboard.Score, 2, "key2")
      Leaderboard.select(Leaderboard.Score, :descend, 2)
      #=> [{3, "key3"}, {2, "key2"}]
      Leaderboard.select(Leaderboard.Score, :ascend, 2)
      #=> [{1, "key1"}, {2, "key2"}]

  Usually, the leaderboard is started as a part of a supervision tree:

      worker(Leaderboard, [Leaderboard.Score])

  When a key is already present and it is inserted again, the score associated
  with the given key gets updated (`insert/3` works as update function as
  well).

  Note that all the write operations such as `insert/3` and `delete/2` (as
  opposed to the read operations) are serialised via the `GenServer` process.
  """

  use GenServer

  @typedoc """
  Name of the leaderboard
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
  @type score :: term

  @typedoc """
  Key associated with a score
  """
  @type key :: term

  @typedoc """
  Score and key together
  """
  @type record :: {score, key}

  @typedoc """
  Match specification
  """
  @type match_spec :: :ets.match_spec

  @typedoc """
  Order of returned records
  """
  @type order :: :ascend | :descend

  @typedoc """
  The max number of records to return (or all of them)
  """
  @type limit :: pos_integer | :all

  @doc """
  Starts `GenServer` process with link to the current process.

  The `table_name` must be an atom, based on which ETS leaderboard tables
  are created. The `GenServer` process is the owner of the ETS tables.
  """
  @spec start_link(table_name, options) :: on_start
  def start_link(table_name, options \\ []) do
    GenServer.start_link(__MODULE__, [table_name], options)
  end

  @doc """
  Starts `GenServer` process without links.
  """
  @spec start(table_name, options) :: on_start
  def start(table_name, options \\ []) do
    GenServer.start(__MODULE__, [table_name], options)
  end

  @doc """
  Deletes a record based on the `key`.
  """
  @spec delete(table_name, key, timeout) :: boolean
  def delete(table_name, key, timeout \\ 5000) do
    server = Leaderboard.Table.server_pid(table_name)
    GenServer.call(server, {:delete, key}, timeout)
  end

  @doc """
  Deletes all the records.
  """
  @spec delete_all(table_name, timeout) :: :ok
  def delete_all(table_name, timeout \\ 5000) do
    server = Leaderboard.Table.server_pid(table_name)
    GenServer.call(server, :delete_all, timeout)
  end

  @doc """
  Inserts a new record or updates the `score` of an existing `key`.
  """
  @spec insert(table_name, score, key, timeout) :: :ok
  def insert(table_name, score, key, timeout \\ 5000) do
    server = Leaderboard.Table.server_pid(table_name)
    GenServer.call(server, {:insert, score, key}, timeout)
  end

  @doc """
  Returns a `score` associated with a `key`.
  """
  @spec lookup(table_name, key) :: score | nil
  def lookup(table_name, key) do
    Leaderboard.Table.lookup(table_name, key)
  end

  @doc """
  Returns all the values as defined in `match_spec`.

  The returned values don't have to be records in form of
  `{score, key}`. The values are matched using the `match_spec` and they
  are ordered in specified `order`.

  For example, the `match_spec` to return all the records is
  `[{{:"$1"}, [], [:"$1"]}]`.

  """
  @spec match(table_name, match_spec, order) :: [term]
  def match(table_name, match_spec, order) do
    score_table = Leaderboard.Table.score_table_name(table_name)
    Leaderboard.Table.match(score_table, match_spec, order, :all)
  end

  @doc """
  Behaves the same as `match/3`, but also has `limit` that defines the max
  number of returned values.
  """
  @spec match(table_name, match_spec, order, limit) :: [term]
  def match(table_name, match_spec, order, limit) do
    score_table = Leaderboard.Table.score_table_name(table_name)
    Leaderboard.Table.match(score_table, match_spec, order, limit)
  end

  @doc """
  Returns all the records ordered in specified `order`.
  """
  @spec select(table_name, order) :: [record]
  def select(table_name, order) do
    score_table = Leaderboard.Table.score_table_name(table_name)
    Leaderboard.Table.select(score_table, order, :all)
  end

  @doc """
  Behaves the same as `select/2`, but also has `limit` that defines the max
  number of returned records.
  """
  @spec select(table_name, order, limit) :: [record]
  def select(table_name, order, limit) do
    score_table = Leaderboard.Table.score_table_name(table_name)
    Leaderboard.Table.select(score_table, order, limit)
  end

  @doc """
  Returns the number of records in the table.
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
    Leaderboard.Table.insert(score_table, key_table, score, key)
    {:reply, :ok, state}
  end
  def handle_call({:delete, key}, _from,
      %{score_table: score_table, key_table: key_table} = state) do
    reply = Leaderboard.Table.delete(score_table, key_table, key)
    {:reply, reply, state}
  end
  def handle_call(:delete_all, _from,
      %{score_table: score_table, key_table: key_table} = state) do
    Leaderboard.Table.delete_all(score_table, key_table)
    {:reply, :ok, state}
  end
end

defmodule Leaderboard.Table do
  @moduledoc false

  @server_key :"$server_pid"
  @match_spec_all [{{:"$1"}, [], [:"$1"]}]

  def init_score_table(key_table) do
    table_name = score_table_name(key_table)
    :ets.new(table_name, [:ordered_set, :protected, :named_table,
                          read_concurrency: true])
  end

  def init_key_table(key_table, server_pid) do
    :ets.new(key_table, [:set, :protected, :named_table,
                           read_concurrency: true])
    insert_server_pid(key_table, server_pid)
    key_table
  end

  def server_pid(key_table) do
    lookup_server_pid(key_table)
  end

  def score_table_name(key_table) do
    # Append "Score" to key_table
    Module.concat(key_table, "Score")
  end

  def delete(score_table, key_table, key) do
    case :ets.lookup(key_table, key) do
      [{^key, score}] ->
          :ets.delete(key_table, key)
          :ets.delete(score_table, {score, key})
          true
      [] ->
          false
    end
  end

  def delete_all(score_table, key_table) do
    server_pid = lookup_server_pid(key_table)
    :ets.delete_all_objects(score_table)
    :ets.delete_all_objects(key_table)
    insert_server_pid(key_table, server_pid)
  end

  def insert(score_table, key_table, score, key) do
    # score_table has just key which is {score, key}, there is no value
    # associated with the key.
    :ets.insert(score_table, {{score, key}})
    :ets.insert(key_table, {key, score})
  end

  def lookup(key_table, key) do
    case :ets.lookup(key_table, key) do
      [{^key, score}] -> score
      [] -> nil
    end
  end

  def match(score_table, match_spec, :descend, :all) do
    score_table
    |> :ets.select_reverse(match_spec)
    |> match_result()
  end
  def match(score_table, match_spec, :descend, limit) do
    score_table
    |> :ets.select_reverse(match_spec, limit)
    |> match_result()
  end
  def match(score_table, match_spec, :ascend, :all) do
    score_table
    |> :ets.select(match_spec)
    |> match_result()
  end
  def match(score_table, match_spec, :ascend, limit) do
    score_table
    |> :ets.select(match_spec, limit)
    |> match_result()
  end

  def select(score_table, :descend, 1) do
    score_table
    |> :ets.last()
    |> single_select_result()
  end
  def select(score_table, :ascend, 1) do
    score_table
    |> :ets.first()
    |> single_select_result()
  end
  def select(score_table, order, limit) do
    match(score_table, @match_spec_all, order, limit)
  end

  def size(key_table) do
    :ets.info(key_table, :size) - 1
  end

  defp insert_server_pid(key_table, server_pid) do
    :ets.insert(key_table, {@server_key, server_pid})
  end

  defp lookup_server_pid(key_table) do
    [{@server_key, pid}] = :ets.lookup(key_table, @server_key)
    pid
  end

  defp single_select_result({_score, _key} = record), do: [record]
  defp single_select_result(_), do: []

  defp match_result({records, _cont}), do: records
  defp match_result(records) when is_list(records), do: records
  defp match_result(_), do: []
end
