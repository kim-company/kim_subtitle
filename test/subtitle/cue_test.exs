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

  describe "split/3" do
    test "does not split short sentences" do
      cue = %Cue{
        text: "Keine Nebengeräusche",
        from: 0,
        to: 2000
      }

      assert Cue.split(cue, 10, 37) == [cue]
    end

    test "wraps very long words" do
      input = %Cue{
        text: "KeineNeben-geräuschevonihnenhören.",
        from: 0,
        to: 2000
      }

      expected = [
        %Cue{from: 0, to: 628, text: "KeineNeben-"},
        %Cue{from: 629, to: 1485, text: "geräuschevonih-"},
        %Cue{from: 1486, to: 2000, text: "nenhören."}
      ]

      assert Cue.split(input, 10, 15) == expected
    end

    test "splits a long sentence into multiple lines" do
      input = %Cue{
        text: "Keine Nebengeräusche von ihnen hören.",
        from: 0,
        to: 2000
      }

      expected = [
        %Cue{from: 0, to: 1110, text: "Keine Nebengeräusche"},
        %Cue{from: 1111, to: 2000, text: "von ihnen hören."}
      ]

      assert Cue.split(input, 10, 32) == expected
    end

    test "splits a sentence that fits into mutliple lines" do
      input = %Cue{
        text: "Keine Nebengeräusche von ihnen hören.",
        from: 0,
        to: 2000
      }

      assert Cue.split(input, 10, 37) == [input]
    end
  end
end
