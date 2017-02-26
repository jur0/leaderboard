defmodule LeaderboardBench do
  use Benchfella
  import Enum, only: [each: 2, random: 1]

  @table_1000 Leaderboard1000
  @table_10000 Leaderboard10000
  @table_100000 Leaderboard100000
  @table_1000000 Leaderboard1000000

  @max_score_1000 500
  @max_score_10000 2000
  @max_score_100000 10000
  @max_score_1000000 100000

  setup_all do
    Leaderboard.start(@table_1000)
    Leaderboard.start(@table_10000)
    Leaderboard.start(@table_100000)
    Leaderboard.start(@table_1000000)

    each(1..1000, &Leaderboard.insert(@table_1000, random(1..@max_score_1000), &1))
    each(1..10000, &Leaderboard.insert(@table_10000, random(1..@max_score_10000), &1))
    each(1..100000, &Leaderboard.insert(@table_100000, random(1..@max_score_100000), &1))
    each(1..1000000, &Leaderboard.insert(@table_1000000, random(1..@max_score_1000000), &1))

    {:ok, []}
  end

  bench "Insert to table of size 1000" do
    Leaderboard.insert(@table_1000, random(1..@max_score_1000), random(1000..1500))
    :ok
  end

  bench "Insert to table of size 10000" do
    Leaderboard.insert(@table_10000, random(1..@max_score_10000), random(10000..15000))
    :ok
  end

  bench "Insert to table of size 100000" do
    Leaderboard.insert(@table_100000, random(1..@max_score_100000), random(100000..150000))
    :ok
  end

  bench "Insert to table of size 1000000" do
    Leaderboard.insert(@table_1000000, random(1..@max_score_1000000), random(1000000..1050000))
    :ok
  end
end
