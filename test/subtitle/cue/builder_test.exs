defmodule Subtitle.Cue.BuilderTest do
  use ExUnit.Case, async: true
  alias Subtitle.Cue
  alias Subtitle.Cue.Builder

  describe "new/1" do
    test "returns a new builder" do
      b = Builder.new(min_duration: 999)
      assert b.min_duration == 999
    end

    test "validates the options" do
      assert_raise ArgumentError, fn ->
        Builder.new(test: :hello)
      end
    end
  end

  describe "put/1" do
    test "accepts a cue as an input" do
      b = Builder.new()
      Builder.put(b, %Cue{text: "Hello", from: 0, to: 1000})
    end
  end

  describe "build_cues/1" do
    test "merges successfully two lines" do
      b =
        Builder.new(min_duration: 0, max_duration: 1000)
        |> Builder.put(%Cue{text: "Hallo wie geht es dir?", from: 0, to: 400})
        |> Builder.put(%Cue{text: "Hallo", from: 401, to: 900})

      expected = [%Cue{text: "Hallo wie geht es dir?\nHallo", from: 0, to: 900}]
      assert {_, ^expected} = Builder.build_cues(b)
    end

    test "returns the single buffer" do
      b =
        Builder.new(min_duration: 0, max_duration: 1000)
        |> Builder.put(%Cue{text: "Hallo wie geht es dir?", from: 0, to: 400})

      expected = [%Cue{text: "Hallo wie geht es dir?", from: 0, to: 400}]
      assert {_, ^expected} = Builder.build_cues(b)
    end

    test "returns an empty list if pending is null" do
      {_b, cues} = Builder.new() |> Builder.build_cues()
      assert cues == []
    end
  end
end
