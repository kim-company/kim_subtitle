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

  describe "extend/2" do
    test "extends short cues" do
      cue = %Cue{from: 1, to: 100, text: "Hello"}
      assert Cue.extend(cue, 1000) == %Cue{from: 1, to: 1001, text: "Hello"}
    end

    test "doesnt touch long cues" do
      cue = %Cue{from: 1, to: 10000, text: "Hello"}
      assert Cue.extend(cue, 1000) == cue
    end
  end

  describe "cut/2" do
    test "cuts long cues" do
      cue = %Cue{from: 1, to: 10000, text: "Hello"}
      assert Cue.cut(cue, 1000) == %Cue{from: 1, to: 1001, text: "Hello"}
    end

    test "doesnt touch short cues" do
      cue = %Cue{from: 1, to: 100, text: "Hello"}
      assert Cue.cut(cue, 1000) == cue
    end
  end

  describe "align/1" do
    test "removes overlaps and aligns the cues" do
      input = [
        %Cue{from: 0, to: 1000, text: "1"},
        %Cue{from: 900, to: 1000, text: "2"},
        %Cue{from: 1050, to: 1550, text: "3"}
      ]

      output = [
        %Cue{from: 0, to: 1000, text: "1"},
        %Cue{from: 1001, to: 1101, text: "2"},
        %Cue{from: 1102, to: 1602, text: "3"}
      ]

      assert Cue.align(input) == output
    end
  end

  describe "split/3" do
    test "does not split short sentences" do
      cue = %Cue{
        text: "Keine Nebengeräusche",
        from: 0,
        to: 2000
      }

      assert Cue.split(cue, min_length: 10, max_length: 37) == [cue]
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

      assert Cue.split(input, min_length: 10, max_length: 15) == expected
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

      assert Cue.split(input, min_length: 10, max_length: 32) == expected
    end

    test "splits a sentence that fits into mutliple lines" do
      input = %Cue{
        text: "Keine Nebengeräusche von ihnen hören.",
        from: 0,
        to: 2000
      }

      assert Cue.split(input, min_length: 10, max_length: 37) == [input]
    end
  end
end
