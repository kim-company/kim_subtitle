defmodule Subtitle.WebVTTTest do
  use ExUnit.Case

  alias Subtitle.WebVTT
  alias Subtitle.Helpers
  alias Subtitle.WebVTT.HeaderLine

  describe "unmarshal/1" do
    test "simplest possible" do
      input = """
      WEBVTT

      """

      assert {:ok, webvtt} = WebVTT.unmarshal(input)
      assert [] == webvtt.cues
      assert [%HeaderLine{key: :description, original: "WEBVTT", data: %{}}] == webvtt.header
    end

    test "with header text" do
      input = """
      WEBVTT - This file has no cues.
      But it has a two line description.

      """

      assert {:ok, webvtt} = WebVTT.unmarshal(input)

      assert [
               %HeaderLine{
                 key: :description,
                 original: "WEBVTT - This file has no cues.",
                 data: %{}
               },
               %HeaderLine{
                 key: :description,
                 original: "But it has a two line description.",
                 data: %{}
               }
             ] == webvtt.header
    end

    test "common with header and cues" do
      input = """
      WEBVTT - This file has cues.

      14
      00:01:14.815 --> 00:01:18.114
      - What?
      - Where are we now?

      15
      00:01:18.171 --> 00:01:20.991
      - This is big bat country.

      16
      00:01:21.058 --> 00:01:23.868
      - [ Bats Screeching ]
      - They won't get in your hair. They're after the bugs.

      """

      assert {:ok, webvtt} = WebVTT.unmarshal(input)

      assert [
               %Subtitle.Cue{
                 id: "14",
                 from: Helpers.to_ms(1, 14, 815),
                 to: Helpers.to_ms(1, 18, 114),
                 payload: ~s/- What?\n- Where are we now?/
               },
               %Subtitle.Cue{
                 id: "15",
                 from: Helpers.to_ms(1, 18, 171),
                 to: Helpers.to_ms(1, 20, 991),
                 payload: ~s/- This is big bat country./
               },
               %Subtitle.Cue{
                 id: "16",
                 from: Helpers.to_ms(1, 21, 58),
                 to: Helpers.to_ms(1, 23, 868),
                 payload:
                   ~s/- [ Bats Screeching ]\n- They won't get in your hair. They're after the bugs./
               }
             ] == webvtt.cues
    end

    test "without cue idenfitiers" do
      input = """
      WEBVTT

      04:02.500 --> 04:05.000
      J'ai commencé le basket à l'âge de 13, 14 ans

      04:05.001 --> 04:07.800
      Sur les <i.foreignphrase><lang en>playground</lang></i>, ici à Montpellier

      """

      assert {:ok, webvtt} = WebVTT.unmarshal(input)

      assert [
               %Subtitle.Cue{
                 id: "",
                 from: Helpers.to_ms(4, 2, 500),
                 to: Helpers.to_ms(4, 5, 0),
                 payload: ~s/J'ai commencé le basket à l'âge de 13, 14 ans/
               },
               %Subtitle.Cue{
                 id: "",
                 from: Helpers.to_ms(4, 5, 1),
                 to: Helpers.to_ms(4, 7, 800),
                 payload:
                   ~s|Sur les <i.foreignphrase><lang en>playground</lang></i>, ici à Montpellier|
               }
             ] == webvtt.cues
    end

    test "with X-TIMESTAMP-MAP in the header" do
      # See https://datatracker.ietf.org/doc/html/draft-pantos-http-live-streaming-22#section-3.5
      input = """
      WEBVTT with a note
      and another one
      X-TIMESTAMP-MAP=MPEGTS:181083,LOCAL:00:00:00.000

      00:44:13.215 --> 00:44:17.881
      Deshalb sollte sollten die Empfehlung
      bis Ende März vorgelegt werden.

      """

      offset = round(181_083 / 90)
      assert {:ok, webvtt} = WebVTT.unmarshal(input)

      assert [
               %Subtitle.Cue{
                 id: "",
                 from: Helpers.to_ms(44, 13, 215) + offset,
                 to: Helpers.to_ms(44, 17, 881) + offset,
                 payload: ~s/Deshalb sollte sollten die Empfehlung\nbis Ende März vorgelegt werden./
               }
             ] == webvtt.cues

      assert [
               %HeaderLine{key: :description, original: "WEBVTT with a note", data: %{}},
               %HeaderLine{key: :description, original: "and another one", data: %{}},
               %HeaderLine{
                 key: :x_timestamp_map,
                 original: "X-TIMESTAMP-MAP=MPEGTS:181083,LOCAL:00:00:00.000",
                 data: %{offset: offset}
               }
             ] == webvtt.header
    end

    @tag skip: true
    test "with speaker tags" do
      input = """
      WEBVTT

      00:11.000 --> 00:13.000
      <v Roger Bingham>We are in New York City

      00:30.500 --> 00:32.500
      <v Neil deGrasse Tyson>Didn't we talk about enough in that conversation?
      """
      assert {:ok, webvtt} = WebVTT.unmarshal(input)

      assert [
        "We are in New York City",
        "Didn't we talk about enough in that conversation?"
      ]

      IO.inspect(webvtt)
      assert false
    end

    test "regression#1" do
      input = """
      WEBVTT
      X-TIMESTAMP-MAP=MPEGTS:181083,LOCAL:00:00:00.000

      """

      assert {:ok, webvtt} = WebVTT.unmarshal(input)
      assert [] == webvtt.cues
    end
  end

  describe "marshal!/1" do
    test "simplest possible" do
      input = """
      WEBVTT

      """

      assert input == input |> WebVTT.unmarshal!() |> WebVTT.marshal!()
    end

    test "with header text" do
      input = """
      WEBVTT - This file has no cues.

      """

      assert input == input |> WebVTT.unmarshal!() |> WebVTT.marshal!()
    end

    test "common with header and cues" do
      input = """
      WEBVTT - This file has cues.

      14
      00:01:14.815 --> 00:01:18.114
      - What?
      - Where are we now?

      15
      00:01:18.171 --> 00:01:20.991
      - This is big bat country.

      16
      00:01:21.058 --> 00:01:23.868
      - [ Bats Screeching ]
      - They won't get in your hair. They're after the bugs.

      """

      assert input == input |> WebVTT.unmarshal!() |> WebVTT.marshal!()
    end

    test "with X-TIMESTAMP-MAP in the header" do
      input = """
      WEBVTT
      X-TIMESTAMP-MAP=MPEGTS:181083,LOCAL:00:00:00.000

      00:44:13.215 --> 00:44:17.881
      Deshalb sollte sollten die Empfehlung
      bis Ende März vorgelegt werden.

      """

      assert input == input |> WebVTT.unmarshal!() |> WebVTT.marshal!()
    end
  end
end
