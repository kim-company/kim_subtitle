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

  describe "put_and_get/2" do
    test "merges successfully two lines" do
      {_builder, cues} =
        Builder.new(min_duration: 0, max_duration: 1000)
        |> Builder.put_and_get([
          %Cue{text: "Hallo wie geht es dir?", from: 0, to: 400},
          %Cue{text: "Hallo", from: 401, to: 900},
          %Cue{text: "I am incomplete", from: 901, to: 1000}
        ])

      expected = [%Cue{text: "Hallo wie geht es dir?\nHallo", from: 0, to: 900}]
      assert cues == expected
    end

    test "keeps the start duration of the cue correct" do
      {builder, cues} =
        Builder.new(min_duration: 0, max_duration: 9999)
        |> Builder.put_and_get(%Subtitle.Cue{
          from: 1447,
          to: 5015,
          text: "Volete offrire al vostro cliente finale diversi servizi e video come pacchetto?"
        })

      expected = [
        %Cue{text: "Volete offrire al vostro\ncliente finale diversi", from: 1447, to: 3399}
      ]

      assert cues == expected

      {_builder, cue} = Builder.flush(builder)

      assert cue == %Subtitle.Cue{
               from: 3400,
               to: 5015,
               text: "servizi e video come\npacchetto?"
             }
    end

    test "returns the single buffer" do
      {_builder, cues} =
        Builder.new(min_duration: 0, max_duration: 1000)
        |> Builder.put_and_get([
          %Cue{text: "Hallo wie geht es dir?", from: 0, to: 400},
          %Cue{text: "I am incomplete", from: 1000, to: 5000}
        ])

      expected = [%Cue{text: "Hallo wie geht es dir?", from: 0, to: 400}]
      assert cues == expected
    end

    test "extends and aligns cues to the minimum duration" do
      builder = Builder.new(min_duration: 1000, max_duration: 9999)

      {builder, cues} =
        Builder.put_and_get(builder, [
          %Cue{text: "Line1\nLine2", from: 0, to: 500},
          %Cue{text: "Line1\nLine2", from: 501, to: 1000}
        ])

      assert [%Cue{from: 0, to: 1000}] = cues

      {_builder, cue} = Builder.flush(builder)
      assert %Cue{from: 1001, to: 2001} = cue
    end
  end

  describe "flush/1" do
    test "when there is no pending cue" do
      builder = Builder.new()
      assert Builder.flush(builder) == {builder, nil}
    end

    test "when there is a pending cue" do
      cue = %Cue{text: "Hello", from: 0, to: 2000}
      builder = Builder.new()
      {builder, []} = Builder.put_and_get(builder, cue)

      assert {builder, ^cue} = Builder.flush(builder)
      assert Builder.flush(builder) == {builder, nil}
    end
  end
end
