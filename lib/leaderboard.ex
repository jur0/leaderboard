defmodule Leaderboard do
  @moduledoc """
  Documentation for Leaderboard.
  """

  use GenServer

  def start_link(table_name, options \\ []) do
    GenServer.start_link(__MODULE__, [table_name], options)
  end

  def delete(table_name, value) do
    server = Leaderboard.Table.server_pid(table_name)
    GenServer.call(server, {:delete, value})
  end

  def insert(table_name, score, value) do
    server = Leaderboard.Table.server_pid(table_name)
    GenServer.call(server, {:insert, score, value})
  end

  def lookup(table_name, value) do
    Leaderboard.Table.lookup(table_name, value)
  end

  def match(table_name, match_spec, order) do
    Leaderboard.Table.match(table_name, match_spec, order, :all)
  end

  def match(table_name, match_spec, order, limit) do
    Leaderboard.Table.match(table_name, match_spec, order, limit)
  end

  def select(table_name, order) do
    Leaderboard.Table.select(table_name, order, :all)
  end

  def select(table_name, order, limit) do
    Leaderboard.Table.select(table_name, order, limit)
  end

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

  def init_score_table(value_table) do
    table_name = score_table_name(value_table)
    :ets.new(table_name, [:ordered_set, :protected, :named_table,
                          read_concurrency: true])
  end

  def init_value_table(value_table, server_pid) do
    :ets.new(value_table, [:set, :protected, :named_table,
                           read_concurrency: true])
    :ets.insert(value_table, {@server_key, server_pid})
    value_table
  end

  def server_pid(value_table) do
    [{@server_key, pid}] = :ets.lookup(value_table, @server_key)
    pid
  end

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

  def insert(score, value, score_table, value_table) do
    # Score table has only key value which is {score, value}. It has type
    # :ordered set, so all keys must be unique. If just score was in the key
    # there couldn't be 2 and more records with the same score.
    :ets.insert(score_table, {{score, value}})
    :ets.insert(value_table, {value, score})
  end

  def lookup(value_table, value) do
    case :ets.lookup(value_table, value) do
      [{^value, score}] -> score
      [] -> nil
    end
  end

  def match(value_table, match_spec, order, limit) do
    score_table = score_table_name(value_table)
    perform_match(score_table, match_spec, order, limit)
  end

  def select(value_table, order, 1) do
    score_table = score_table_name(value_table)
    perform_single_select(score_table, order)
  end
  def select(value_table, order, limit) do
    match(value_table, @match_spec_all, order, limit)
  end

  def size(value_table) do
    :ets.info(value_table, :size) - 1
  end

  defp score_table_name(value_table) do
    # Append "Score" to value_table
    Module.concat(value_table, "Score")
  end

  defp perform_single_select(table, :descend) do
    :ets.last(table)
    |> normalize_single_select_result
  end
  defp perform_single_select(table, :ascend) do
    :ets.first(table)
    |> normalize_single_select_result
  end

  defp normalize_single_select_result({_score, _value} = record), do: [record]
  defp normalize_single_select_result(_), do: []

  defp perform_match(table, match_spec, :descend, :all) do
    :ets.select_reverse(table, match_spec)
    |> normalize_match_result
  end
  defp perform_match(table, match_spec, :descend, limit) do
    :ets.select_reverse(table, match_spec, limit)
    |> normalize_match_result
  end
  defp perform_match(table, match_spec, :ascend, :all) do
    :ets.select(table, match_spec)
    |> normalize_match_result
  end
  defp perform_match(table, match_spec, :ascend, limit) do
    :ets.select(table, match_spec, limit)
    |> normalize_match_result
  end

  defp normalize_match_result({records, _cont}), do: records
  defp normalize_match_result(records) when is_list(records), do: records
  defp normalize_match_result(_), do: []
end
