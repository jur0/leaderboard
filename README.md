# Leaderboard

[![Travis](https://travis-ci.org/jur0/leaderboard.svg?branch=master)](https://travis-ci.org/jur0/leaderboard)
[![Hex.pm](https://img.shields.io/hexpm/v/leaderboard.svg)](https://hex.pm/packages/leaderboard)

Leaderboard (rank table) implementation using ETS tables.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `leaderboard` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:leaderboard, "~> 0.2"}]
end
```

## Usage

First off, the leaderboard `GenServer` process must be started. Typically, it's
started as a part of the supervision tree:

  ```elixir
  worker(Leaderboard, [Leaderboard.Test])
  ```

It requires `table_name` argument which is the name of the leaderboard. It
must be an atom. The leaderboard tables shouldn't be started dynamically
as the leaderboard names are atoms and they shouldn't be generated
dynamically.

The leaderboard's API has functions for inserting, updating and deleting
records. These are write functions and are serialised. Also, there are functions
for reading records in specific order and/or with limited number of returned
values:

  ```elixir
  Leaderboard.insert(Leaderboard.Test, 30, "foo")
  Leaderboard.insert(Leaderboard.Test, 5, "bar")
  Leaderboard.insert(Leaderboard.Test, 19, "baz")

  # update "bar" to 10
  Leaderboard.insert(Leaderboard.Test, 10, "bar")

  # lookup the score of "bar"
  Leaderboard.lookup(Leaderboard.Test, "bar")
  #=> 10

  # select top 2 records in ascending order
  Leaderboard.select(Leaderboard.Test, :ascend, 2)
  #=> [{10, "bar"}, {19, "baz"}]

  # match all records that have score > 10 in descending order and return
  # their keys
  match_spec = [{{{:"$1",:"$2"}}, [{:">", :"$1", 10}], [:"$2"]}]
  Leaderboard.match(Leaderboard.Test, match_spec, :descend)
  #=> ["foo", "baz"]

  # delete "foo" record
  Leaderboard.delete(Leaderboard.Test, "foo")
  ```

## Implementation

The leaderboard is composed of a `GenServer` process and two ETS tables. The
ETS `key_table` is of type `:set`:

| key   | value   |
| ----- | ------- |
| `key` | `score` |

The second ETS table called `score_table` is of type `:ordered_set`.
It stores only keys without any values:

| key            | value |
| -------------- | :---: |
| `{score, key}` | -     |

When a new record is inserted into the leaderboard, the record is inserted
into both tables. All the writes are serialised via the `GenServer` process.

The ETS tables are `:protected`, so only the `GenServer` process that owns
them can write. All the other processes are allowed just to read. Read
operations are not serialised so they can be done in concurrent manner.

## Benchmarks

The `score_table` is `:ordered_set`. With the size of the table also
increases the time needed for insert operation:

```
## LeaderboardBench
benchmark name                   iterations   average time
Insert to table of size 1000         200000   8.42 µs/op
Insert to table of size 10000        200000   9.37 µs/op
Insert to table of size 100000       200000   10.06 µs/op
Insert to table of size 1000000      100000   10.55 µs/op
```
