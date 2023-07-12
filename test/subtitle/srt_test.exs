defmodule Subtitle.SRTTest do
  use ExUnit.Case
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
end
