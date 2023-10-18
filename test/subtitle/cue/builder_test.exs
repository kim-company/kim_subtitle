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
    test "with voice tags" do
      cues = [
        %Cue{
          from: 0,
          to: 9_000,
          text:
            "<v Roger Bingham>We're actually at the Lucern Hotel, just down the street from the American Museum of Natural History And with me is Neil deGrasse Tyson Astrophysicist, Director of the Hayden Planetarium at the AMNH."
        }
      ]

      builder = Builder.new()
      {_builder, cues} = Builder.put_and_get(builder, cues, flush: true)

      expected = [
        %Cue{
          from: 0,
          to: 2971,
          text:
            "<v Roger Bingham>We're actually at the Lucern Hotel,\njust down the street from the</v>",
          id: ""
        },
        %Cue{
          from: 2972,
          to: 5779,
          text:
            "<v Roger Bingham>American Museum of Natural History\nAnd with me is Neil deGrasse Tyson</v>",
          id: ""
        },
        %Cue{
          from: 5780,
          to: 9000,
          text:
            "<v Roger Bingham>Astrophysicist, Director of the\nHayden Planetarium at the AMNH.</v>",
          id: ""
        }
      ]

      assert cues == expected
    end

    test "does not create excessive delay" do
      cues = [
        %Cue{
          from: 490_538,
          to: 496_837,
          text:
            "Und das Schöne ist, dass es eine Standortrundreise ist, also Busrundreise könnte man ja auch denken."
        },
        %Cue{from: 499_659, to: 500_888, text: "immer ein und auspacken."},
        %Cue{from: 510_098, to: 511_882, text: "um 86 % weiter."},
        %Cue{from: 511_899, to: 514_176, text: "Empfehlungsrate über 5000 Bewertungen."},
        %Cue{from: 514_659, to: 515_828, text: "den deutschsprachigen Urlaubern."},
        %Cue{from: 515_828, to: 517_658, text: "Ein sehr beliebtes Hotel."},
        %Cue{from: 517_988, to: 520_088, text: "Und da sehen wir es auch."},
        %Cue{
          from: 524_439,
          to: 531_698,
          text:
            "Und das bedeutet in dem Fall, dass Sie noch zwei Getränke pro Person und Abendessen inklusive haben."
        },
        %Cue{
          from: 532_749,
          to: 535_568,
          text: "wir sie dann immer ab mit der deutschsprachigen Reiseleitung."
        },
        %Cue{
          from: 535_568,
          to: 541_448,
          text:
            "Und dann erleben sie tatsächlich dieses Mallorca für alle Sinne, können sich zwischendurch Massagen gönnen."
        },
        %Cue{
          from: 552_189,
          to: 556_748,
          text: "Reisezeit, wenn es darum geht, auch so eine Standortrundreise zu machen."
        },
        %Cue{from: 562_209, to: 562_718, text: "Monaten."},
        %Cue{
          from: 562_988,
          to: 566_799,
          text:
            "Da macht es natürlich auch keinen Spaß, weil es viel zu heiß ist und viel zu warm ist."
        },
        %Cue{
          from: 567_068,
          to: 571_508,
          text:
            "Aber da haben wir Ihnen die perfekte Reisezeit rausgesucht, nämlich jetzt noch in diesem Jahr."
        },
        %Cue{from: 571_629, to: 572_168, text: "Oktober."},
        %Cue{
          from: 581_499,
          to: 584_018,
          text: "was ja eigentlich auch schon wieder die Sommersaison ist."
        },
        %Cue{from: 586_659, to: 590_858, text: "zwei Preise, nämlich 699 € oder 749 €."},
        %Cue{
          from: 591_008,
          to: 594_428,
          text: "Das Ausflug spaket im Wert von 760 € ist schon mit drin."
        },
        %Cue{from: 601_269, to: 602_754, text: "alles organisiert für Sie."},
        %Cue{from: 643_149, to: 644_738, text: "Badebucht garantiert."}
      ]

      assert measure_comulative_delay(Builder.new(), cues) <= 100
    end

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

      assert [%Cue{from: 1447}] = cues

      {_builder, cue} = Builder.flush(builder)

      assert %Subtitle.Cue{} = cue
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

  def measure_comulative_delay(builder, cues) do
    cues
    |> Enum.reduce({builder, 0}, fn cue, {builder, delay} ->
      last = builder.last

      delay =
        if last != nil and last.to > cue.from do
          delay + (last.to - cue.from)
        else
          delay
        end

      {builder, _ready} = Builder.put_and_get(builder, cue)
      {builder, delay}
    end)
    |> elem(1)
  end
end
