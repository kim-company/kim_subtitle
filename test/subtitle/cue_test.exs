defmodule Subtitle.CueTest do
  use ExUnit.Case, async: true

  alias Subtitle.Cue

  describe "merge/3" do
    test "merges cues if its ok" do
      cue1 = %Cue{from: 0, to: 10, text: "Hello, how are you?"}
      cue2 = %Cue{from: 11, to: 20, text: "I'm fine. Thanks"}

      expected = %Cue{
        text: "Hello, how are you?\nI'm fine. Thanks",
        from: 0,
        to: 20
      }

      assert Cue.merge(cue1, cue2) == {:ok, expected}
    end

    test "does not merge cues if there are too many lines" do
      cue1 = %Cue{from: 0, to: 10, text: "Hello, how are you?\nBad."}
      cue2 = %Cue{from: 11, to: 20, text: "I'm fine. Thanks"}

      assert Cue.merge(cue1, cue2, max_lines: 2) == {:error, :too_many_lines}
    end

    test "does not merge cues if duration exceeds the maximum" do
      cue1 = %Cue{from: 0, to: 10, text: "Hello, how are you?"}
      cue2 = %Cue{from: 11, to: 20, text: "I'm fine. Thanks"}

      assert Cue.merge(cue1, cue2, max_duration: 15) == {:error, :max_duration_exceeded}
    end

    test "does not merge if gap between cues is to big" do
      cue1 = %Cue{from: 0, to: 10, text: "Hello, how are you?"}
      cue2 = %Cue{from: 300, to: 340, text: "I'm fine. Thanks"}

      assert Cue.merge(cue1, cue2) == {:error, :gap_too_big}
    end

    test "corrects tags while merging" do
      cue1 = %Cue{from: 0, to: 10, text: "<v UU>All right, everyone."}
      cue2 = %Cue{from: 11, to: 20, text: "<v UU>Okay, alle zusammen."}

      expected = %Cue{
        text: "<v UU>All right, everyone.</v>\n<v UU>Okay, alle zusammen.</v>",
        from: 0,
        to: 20
      }

      assert Cue.merge(cue1, cue2) == {:ok, expected}
    end
  end

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

  describe "split/2" do
    test "trims and discards empty cues" do
      cue = %Cue{text: " ", from: 0, to: 200}
      assert Cue.split(cue) == []
    end

    test "does not split short sentences" do
      cue = %Cue{
        text: "Keine Nebengeräusche",
        from: 0,
        to: 2000
      }

      assert Cue.split(cue, max_length: 37) == [cue]
    end

    test "wraps words on the limit" do
      input = %Cue{
        from: 0,
        to: 1000,
        text:
          "Dies geschieht über APIs oder Anwendungsprogrammierschnittstellen, die es Ihrem Code ermöglichen."
      }

      expected = [
        %Subtitle.Cue{from: 0, text: "Dies geschieht über APIs oder", to: 260},
        %Subtitle.Cue{from: 261, text: "Anwendungsprogrammierschnittstellen,", to: 656},
        %Subtitle.Cue{from: 657, text: "die es Ihrem Code ermöglichen.", to: 998}
      ]

      assert Cue.split(input, max_length: 37) == expected
    end

    test "wraps very long words" do
      input = %Cue{
        text: "KeineNeben-geräuschevonihnenhören.",
        from: 0,
        to: 2000
      }

      expected = [
        %Cue{from: 0, to: 511, text: "KeineNeben-"},
        %Cue{from: 512, to: 1209, text: "geräuschevonih-"},
        %Cue{from: 1210, to: 2000, text: "nenhören."}
      ]

      assert Cue.split(input, max_length: 15) == expected
    end

    test "splits a long sentence into multiple lines" do
      input = %Cue{
        text: "Keine Nebengeräusche von ihnen hören.",
        from: 0,
        to: 2000
      }

      expected = [
        %Cue{from: 0, to: 908, text: "Keine Nebengeräusche"},
        %Cue{from: 909, to: 2000, text: "von ihnen hören."}
      ]

      assert Cue.split(input, max_length: 32) == expected
    end

    test "splits a sentence that fits into mutliple lines" do
      input = %Cue{
        text: "Keine Nebengeräusche von ihnen hören.",
        from: 0,
        to: 2000
      }

      assert Cue.split(input, max_length: 37) == [input]
    end
  end

  describe "to_paragraphs/1" do
    test "leaves full sentences untouched" do
      input = %Cue{
        text: "Keine Nebengeräusche von ihnen hören.",
        from: 0,
        to: 2000
      }

      assert to_paragraphs_flat([input]) == [input.text]
    end

    test "removes newline characters" do
      input = %Cue{
        text: "Keine Nebengeräusche\nvon ihnen hören.\n",
        from: 0,
        to: 2000
      }

      assert to_paragraphs_flat([input]) == ["Keine Nebengeräusche von ihnen hören."]
    end

    test "joins cues that are separated by less than 1ms" do
      input = [
        %Cue{from: 0, to: 908, text: "Keine Nebengeräusche"},
        %Cue{from: 909, to: 2000, text: "von ihnen hören."}
      ]

      assert to_paragraphs_flat(input, silence: 1) == join_cue_text(input)
    end

    test "does not join cues that are separated by more than 1ms" do
      input = [
        %Cue{from: 0, to: 907, text: "Keine Nebengeräusche"},
        %Cue{from: 909, to: 2000, text: "von ihnen hören."}
      ]

      assert Enum.map(input, & &1.text) == ["Keine Nebengeräusche", "von ihnen hören."]

      assert to_paragraphs_flat(input, silence: 1) == Enum.map(input, & &1.text)
    end

    test "silence is tunable" do
      input = [
        %Cue{from: 0, to: 907, text: "Keine Nebengeräusche"},
        %Cue{from: 1908, to: 2000, text: "von ihnen hören."}
      ]

      assert to_paragraphs_flat(input, silence: 1001) == join_cue_text(input)
      assert to_paragraphs_flat(input, silence: 1000) == Enum.map(input, & &1.text)
    end

    test "with speaker tags" do
      cues = [
        %Subtitle.Cue{
          from: 21072,
          to: 25032,
          text: "<v S1>Hallo und willkommen zum</v>\n<v S2>Infrastruktur Review.</v>",
          id: ""
        },
        %Subtitle.Cue{
          from: 27822,
          to: 31767,
          text:
            "<v UU>Vier Seiten einer Übersetzung des</v>\n<v UU>Tetraedingo wird später sagen und</v>",
          id: ""
        },
        %Subtitle.Cue{
          from: 31768,
          to: 36012,
          text: "<v UU>erklären, wie sie übersetzt werden</v>\n<v UU>und wie sie es macht.</v>",
          id: ""
        },
        %Subtitle.Cue{
          from: 36013,
          to: 38083,
          text: "<v UU>Aber ich möchte jetzt anfangen.</v>",
          id: ""
        },
        %Subtitle.Cue{
          from: 38472,
          to: 41142,
          text: "<v S1>Ich bin verrückt.</v>",
          id: ""
        }
      ]

      assert [
               {:speaker, "S1", _},
               {:text, "Hallo und willkommen zum"},
               {:speaker, "S2", _},
               {:text, "Infrastruktur Review."},
               {:speaker, "UU", _},
               {:text,
                "Vier Seiten einer Übersetzung des Tetraedingo wird später sagen und erklären, wie sie übersetzt werden und wie sie es macht. Aber ich möchte jetzt anfangen."},
               {:speaker, "S1", _},
               {:text, "Ich bin verrückt."}
             ] = Cue.to_paragraphs(cues)
    end

    defp to_paragraphs_flat(cues, opts \\ []) do
      cues
      |> Cue.to_paragraphs(opts)
      |> Enum.map(fn {_, text} -> text end)
    end

    defp join_cue_text(cues) do
      Enum.map(cues, & &1.text) |> Enum.join(" ") |> List.wrap()
    end
  end
end
