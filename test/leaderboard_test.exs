defmodule LeaderboardTest do
  use ExUnit.Case, async: false
  doctest Leaderboard

  @table Leaderboard.Test

  test "start leaderboard" do
    {:ok, _pid} = Leaderboard.start_link(@table)
    assert 0 == Leaderboard.size(@table)
  end

  test "delete" do
    {:ok, _pid} = Leaderboard.start_link(@table)
    Leaderboard.insert(@table, {1.9, 2}, :foo)
    Leaderboard.insert(@table, {1.11,10}, :bar)
    assert Leaderboard.delete(@table, "unknown_value") == :ok
    assert Leaderboard.size(@table) == 2
    assert Leaderboard.delete(@table, :foo) == :ok
    assert Leaderboard.delete(@table, :bar) == :ok
    assert Leaderboard.size(@table) == 0
  end

  test "insert" do
    {:ok, _pid} = Leaderboard.start_link(@table)
    Leaderboard.insert(@table, 1, :a)
    Leaderboard.insert(@table, 1, :b)
    Leaderboard.insert(@table, 3, :c)
    assert Leaderboard.size(@table) == 3
  end

  test "insert existing" do
    {:ok, _pid} = Leaderboard.start_link(@table)
    Leaderboard.insert(@table, 1, :a)
    Leaderboard.insert(@table, 5, :a)
    assert Leaderboard.size(@table) == 1
    assert Leaderboard.lookup(@table, :a) == 5
  end

  test "lookup" do
    {:ok, _pid} = Leaderboard.start_link(@table)
    Leaderboard.insert(@table, {20, "aaa"}, "value1")
    Leaderboard.insert(@table, {40, "bbb"}, "value2")
    assert Leaderboard.lookup(@table, "value0") == nil
    assert Leaderboard.lookup(@table, "value1") == {20, "aaa"}
    assert Leaderboard.lookup(@table, "value2") == {40, "bbb"}
  end

  test "select order" do
    {:ok, _pid} = Leaderboard.start_link(@table)
    assert Leaderboard.select(@table, :descend) == nil
    assert Leaderboard.select(@table, :ascend) == nil
    Leaderboard.insert(@table, {"aaa", 1}, "v1")
    Leaderboard.insert(@table, {"aax", 2}, "v3")
    Leaderboard.insert(@table, {"aaa", 2}, "v2")
    assert Leaderboard.select(@table, :ascend) ==
      [{{"aaa", 1}, "v1"}, {{"aaa", 2}, "v2"}, {{"aax", 2}, "v3"}]
    assert Leaderboard.select(@table, :descend) ==
      [{{"aax", 2}, "v3"}, {{"aaa", 2}, "v2"}, {{"aaa", 1}, "v1"}]
  end

  test "select single" do
    {:ok, _pid} = Leaderboard.start_link(@table)
    assert Leaderboard.select(@table, :descend, 1) == nil
    assert Leaderboard.select(@table, :ascend, 1) == nil
    Leaderboard.insert(@table, 200, :foo)
    Leaderboard.insert(@table, 100, :bar)
    assert Leaderboard.select(@table, :ascend, 1) == [{100, :bar}]
    assert Leaderboard.select(@table, :descend, 1) == [{200, :foo}]
  end

  test "multi select" do
    {:ok, _pid} = Leaderboard.start_link(@table)
    assert Leaderboard.select(@table, :descend, :all) == nil
    assert Leaderboard.select(@table, :ascend, 100) == nil
    Leaderboard.insert(@table, {"aax", 2}, "v3")
    Leaderboard.insert(@table, {"aaa", 1}, "v1")
    Leaderboard.insert(@table, {"aaa", 2}, "v2")
    assert Leaderboard.select(@table, :ascend, 2) ==
      [{{"aaa", 1}, "v1"}, {{"aaa", 2}, "v2"}]
    assert Leaderboard.select(@table, :ascend, 10) ==
      [{{"aaa", 1}, "v1"}, {{"aaa", 2}, "v2"}, {{"aax", 2}, "v3"}]
    assert Leaderboard.select(@table, :ascend, :all) ==
      [{{"aaa", 1}, "v1"}, {{"aaa", 2}, "v2"}, {{"aax", 2}, "v3"}]
    assert Leaderboard.select(@table, :descend, 2) ==
      [{{"aax", 2}, "v3"}, {{"aaa", 2}, "v2"}]
    assert Leaderboard.select(@table, :descend, 5) ==
      [{{"aax", 2}, "v3"}, {{"aaa", 2}, "v2"}, {{"aaa", 1}, "v1"}]
    assert Leaderboard.select(@table, :descend, :all) ==
      [{{"aax", 2}, "v3"}, {{"aaa", 2}, "v2"}, {{"aaa", 1}, "v1"}]
  end
end
