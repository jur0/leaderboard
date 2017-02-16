defmodule Leaderboard do
  @moduledoc """
  Documentation for Leaderboard.
  """

  use GenServer

  @type table_name :: atom

  @type match_spec :: Leaderboard.Table.match_spec

  @type order :: Leaderboard.Table.order

  @type limit :: Leaderboard.Table.limit

  @spec start_link(table_name, GenServer.options) :: GenServer.on_start
  def start_link(table_name, options \\ []) do
    GenServer.start_link(__MODULE__, [table_name], options)
  end

  @spec delete(table_name, term) :: boolean
  def delete(table_name, value) do
    server = Leaderboard.Table.server_pid(table_name)
    GenServer.call(server, {:delete, value})
  end

  @spec insert(table_name, term, term) :: :ok
  def insert(table_name, score, value) do
    server = Leaderboard.Table.server_pid(table_name)
    GenServer.call(server, {:insert, score, value})
  end

  @spec lookup(table_name, term) :: term | nil
  def lookup(table_name, value) do
    Leaderboard.Table.lookup(table_name, value)
  end

  @spec match(table_name, match_spec, order) :: [term]
  def match(table_name, match_spec, order) do
    Leaderboard.Table.match(table_name, match_spec, order, :all)
  end

  @spec match(table_name, match_spec, order, limit) :: [term]
  def match(table_name, match_spec, order, limit) do
    Leaderboard.Table.match(table_name, match_spec, order, limit)
  end

  @spec select(table_name, order) :: [term]
  def select(table_name, order) do
    Leaderboard.Table.select(table_name, order, :all)
  end

  @spec select(table_name, order, limit) :: [term]
  def select(table_name, order, limit) do
    Leaderboard.Table.select(table_name, order, limit)
  end

  @spec size(table_name) :: pos_integer
  def size(table_name) do
    Leaderboard.Table.size(table_name)
  end

  # Callbacks

  def init([table_name]) do
    score_table = Leaderboard.Table.init_score_table(table_name)
    value_table = Leaderboard.Table.init_value_table(table_name, self())
    {:ok, %{score_table: score_table, value_table: value_table}}
  end

  def handle_call({:insert, score, value}, _from,
      %{score_table: score_table, value_table: value_table} = state) do
    Leaderboard.Table.delete(value, score_table, value_table)
    Leaderboard.Table.insert(score, value, score_table, value_table)
    {:reply, :ok, state}
  end
  def handle_call({:delete, value}, _from,
      %{score_table: score_table, value_table: value_table} = state) do
    Leaderboard.Table.delete(value, score_table, value_table)
    {:reply, :ok, state}
  end
end

defmodule Leaderboard.Table do
  @moduledoc false

  @server_key :"$server_pid"
  @match_spec_all [{{:"$1"}, [], [:"$1"]}]

  @type score_table :: atom

  @type value_table :: atom

  @type match_spec :: :ets.match_spec

  @type order :: :ascend | :descend

  @type limit :: pos_integer | :all

  @spec init_score_table(value_table) :: score_table
  def init_score_table(value_table) do
    table_name = score_table_name(value_table)
    :ets.new(table_name, [:ordered_set, :protected, :named_table,
                          read_concurrency: true])
  end

  @spec init_value_table(value_table, pid) :: value_table
  def init_value_table(value_table, server_pid) do
    :ets.new(value_table, [:set, :protected, :named_table,
                           read_concurrency: true])
    :ets.insert(value_table, {@server_key, server_pid})
    value_table
  end

  @spec server_pid(value_table) :: pid
  def server_pid(value_table) do
    [{@server_key, pid}] = :ets.lookup(value_table, @server_key)
    pid
  end

  @spec delete(term, score_table, value_table) :: boolean
  def delete(value, score_table, value_table) do
    case :ets.lookup(value_table, value) do
      [{^value, score}] ->
          :ets.delete(value_table, value)
          :ets.delete(score_table, {score, value})
          true
      [] ->
          false
    end
  end

  @spec insert(term, term, score_table, value_table) :: true
  def insert(score, value, score_table, value_table) do
    # Score table has only key value which is {score, value}. It has type
    # :ordered set, so all keys must be unique. If just score was in the key
    # there couldn't be 2 and more records with the same score.
    :ets.insert(score_table, {{score, value}})
    :ets.insert(value_table, {value, score})
  end

  @spec lookup(value_table, term) :: term | nil
  def lookup(value_table, value) do
    case :ets.lookup(value_table, value) do
      [{^value, score}] -> score
      [] -> nil
    end
  end

  @spec match(value_table, match_spec, order, limit) :: [term]
  def match(value_table, match_spec, order, limit) do
    score_table = score_table_name(value_table)
    perform_match(score_table, match_spec, order, limit)
  end

  @spec select(value_table, order, limit) :: [term]
  def select(value_table, order, 1) do
    score_table = score_table_name(value_table)
    perform_single_select(score_table, order)
  end
  def select(value_table, order, limit) do
    match(value_table, @match_spec_all, order, limit)
  end

  @spec size(value_table) :: non_neg_integer
  def size(value_table) do
    :ets.info(value_table, :size) - 1
  end

  defp score_table_name(value_table) do
    # Append "Score" to value_table
    Module.concat(value_table, "Score")
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

  defp single_select_result({_score, _value} = record), do: [record]
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
