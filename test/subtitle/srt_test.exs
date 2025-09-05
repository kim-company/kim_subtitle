defmodule Subtitle.SRTTest do
  use ExUnit.Case, async: true
  alias Subtitle.SRT
  alias Subtitle.Helpers

  describe "unmarshal/1" do
    test "empty file" do
      input = """
      """

      assert {:ok, srt} = SRT.unmarshal(input)
      assert [] == srt.cues
    end

    test "with one cue" do
      input = """
      1
      00:05:00,400 --> 00:05:15,300
      This is an example of
      a subtitle.
      """

      assert {:ok, srt} = SRT.unmarshal(input)

      assert [
               %Subtitle.Cue{
                 id: "1",
                 from: Helpers.to_ms(5, 0, 400),
                 to: Helpers.to_ms(5, 15, 300),
                 text: ~s/This is an example of\na subtitle./
               }
             ] == srt.cues
    end

    test "with two cues" do
      input = """
      1
      00:05:00,400 --> 00:05:15,300
      This is an example of
      a subtitle.

      2
      00:05:16,400 --> 00:05:25,300
      This is an example of
      a subtitle - 2nd subtitle.
      """

      assert {:ok, srt} = SRT.unmarshal(input)

      assert [
               %Subtitle.Cue{
                 id: "1",
                 from: Helpers.to_ms(5, 0, 400),
                 to: Helpers.to_ms(5, 15, 300),
                 text: ~s/This is an example of\na subtitle./
               },
               %Subtitle.Cue{
                 id: "2",
                 from: Helpers.to_ms(5, 16, 400),
                 to: Helpers.to_ms(5, 25, 300),
                 text: ~s/This is an example of\na subtitle - 2nd subtitle./
               }
             ] == srt.cues
    end

    test "with empty cues" do
      # I think this could be invalid but flv2srt, a libcaption tool,
      # produces this kind of stuff as well and we want to be able to
      # extract cues from it.
      input = """
      01
      0:00:01,621 --> 00:00:02,621
      - Never drink liquid nitrogen.

      02
      0:00:02,621 --> 00:00:03,121


      03
      0:00:03,121 --> 00:00:03,121
      - It will perforate your stomach
      - You could die.
      """

      assert {:ok, srt} = SRT.unmarshal(input)

      assert [
               %Subtitle.Cue{
                 id: "01",
                 from: Helpers.to_ms(0, 1, 621),
                 to: Helpers.to_ms(0, 2, 621),
                 text: ~s/- Never drink liquid nitrogen./
               },
               %Subtitle.Cue{
                 id: "03",
                 from: Helpers.to_ms(0, 3, 121),
                 to: Helpers.to_ms(0, 3, 121),
                 text: ~s/- It will perforate your stomach\n- You could die./
               }
             ] == srt.cues
    end

    test "with invalid input" do
      input =
        "01\n0:00:01,621 --> 00:00:02,621\nLSBOZXZlciBkcmluayBsaXF1aWQgbml\n\n02\n0:00:02,621 --> 00:00:02,621\n\n\n"

      assert {:ok, srt} = SRT.unmarshal(input)

      assert [
               %Subtitle.Cue{
                 id: "01",
                 from: Helpers.to_ms(0, 1, 621),
                 to: Helpers.to_ms(0, 2, 621),
                 text: ~s/LSBOZXZlciBkcmluayBsaXF1aWQgbml/
               }
             ] == srt.cues
    end
  end

  describe "marshal/1" do
    test "creates srt from cues" do
      cues = [
        %Subtitle.Cue{
          id: "1",
          from: Helpers.to_ms(0, 0, 498),
          to: Helpers.to_ms(0, 2, 827),
          text: "- Here's what I love most\nabout food and diet."
        },
        %Subtitle.Cue{
          id: nil,
          from: Helpers.to_ms(0, 2, 827),
          to: Helpers.to_ms(0, 6, 383),
          text: "We all eat several times a day,\nand we're totally in charge"
        },
        %Subtitle.Cue{
          id: "",
          from: Helpers.to_ms(0, 6, 383),
          to: Helpers.to_ms(0, 9, 427),
          text: "of what goes on our plate\nand what stays off."
        }
      ]

      assert Subtitle.SRT.marshal!(%Subtitle.SRT{cues: cues}) ==
               String.trim_trailing("""
               1
               00:00:00,498 --> 00:00:02,827
               - Here's what I love most
               about food and diet.

               00:00:02,827 --> 00:00:06,383
               We all eat several times a day,
               and we're totally in charge

               00:00:06,383 --> 00:00:09,427
               of what goes on our plate
               and what stays off.
               """)
    end
  end

  describe "parse_body/1" do
    test "can parse uncomplete srt" do
      input = """
      1
      00:05:00,400 --> 00:05:15,300
      This is an example of
      a subtitle.

      2
      00:04
      """

      cues = [%Subtitle.Cue{
                 id: "1",
                 from: Helpers.to_ms(5, 0, 400),
                 to: Helpers.to_ms(5, 15, 300),
                 text: ~s/This is an example of\na subtitle./
               }]

      assert SRT.parse_body(input) == {:partial, cues, "2\n00:04\n"}
    end

    test "works with iodata" do
      input = [
        "1\n",
        """
        00:05:00,400 --> 00:05:15,300
        This is an example of
        a subtitle.

        """,
        """
        2
        00:04
        """
      ]

      cues = [%Subtitle.Cue{
                 id: "1",
                 from: Helpers.to_ms(5, 0, 400),
                 to: Helpers.to_ms(5, 15, 300),
                 text: ~s/This is an example of\na subtitle./
               }]

      assert SRT.parse_body(input) == {:partial, cues, "2\n00:04\n"}
    end
  end
end
