defmodule Subtitle.CueTest do
  use ExUnit.Case

  alias Subtitle.Cue

  describe "tidy/1" do
    test "does not merge single cue" do
      input = [%Cue{from: 0, to: 3, text: "- What?"}]
      assert input == Cue.tidy(input)
    end

    test "does not merge when it shouldn't" do
      input = [
        %Cue{from: 0, to: 3, text: "- What?"},
        %Cue{from: 3, to: 6, text: "- When?"}
      ]

      assert input == Cue.tidy(input)
    end

    test "merges adjacent cues with the same text" do
      input = [
        %Cue{from: 0, to: 3, text: "- What?"},
        %Cue{from: 3, to: 6, text: "- What?"},
        %Cue{from: 6, to: 8, text: "- What?"}
      ]

      assert [%Cue{from: 0, to: 8, text: "- What?"}] == Cue.tidy(input)
    end
  end
end
