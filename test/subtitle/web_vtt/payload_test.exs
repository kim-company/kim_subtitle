defmodule Subtitle.WebVTT.PayloadTest do
  use ExUnit.Case
  alias Subtitle.WebVTT.Payload
  alias Subtitle.WebVTT.Payload.Tag

  @inputs [
    {"text", {:text, "text", nil}},
    {"<c.classname>text</c>", {:class, "text", "classname"}},
    {"<v Bob>text</v>", {:voice, "text", "Bob"}},
    {"<i>text</i>", {:italics, "text", nil}},
    {"<b>text</b>", {:bold, "text", nil}},
    {"<u>text</u>", {:underline, "text", nil}}
  ]

  # https://developer.mozilla.org/en-US/docs/Web/API/Payload_API#vttcue
  describe "unmarshal!/1" do
    for {input, {type, text, attribute}} <- @inputs do
      test "#{input}" do
        assert [
                 %Tag{
                   type: unquote(type),
                   text: unquote(text),
                   attribute: unquote(attribute)
                 }
               ] =
                 Payload.unmarshal!(unquote(input))
      end
    end

    test "w/o closing tag" do
      assert [%Tag{type: :voice, text: "text", attribute: "Bob"}] ==
               Payload.unmarshal!("<v Bob>text")
    end

    test "w/ newlines" do
      assert [%Tag{type: :voice, text: "Hello\nworld", attribute: "Bob"}] ==
               Payload.unmarshal!("<v Bob>Hello\nworld</v>")
    end
  end

  describe "marshal!/1" do
    for {input, {type, text, attribute}} <- @inputs do
      test "#{input}" do
        tag = %Tag{
          type: unquote(type),
          text: unquote(text),
          attribute: unquote(attribute)
        }

        assert unquote(input) == Payload.marshal!([tag])
      end
    end
  end

  describe "fragment/1" do
    test "simple" do
      assert [%Tag{type: :text, text: "hello"}, %Tag{type: :text, text: "world"}] ==
               Payload.fragment([%Tag{type: :text, text: "hello world"}], 10)
    end

    test "w/ newlines" do
      assert [
               %Tag{type: :voice, text: "Hello", attribute: "Bob"},
               %Tag{type: :voice, text: "world", attribute: "Bob"}
             ] ==
               Payload.fragment([%Tag{type: :voice, text: "Hello\nworld", attribute: "Bob"}], 10)
    end
  end

  describe "simplify/1" do
    test "with repeated voice tag" do
      input =
        "<v Roger Bingham>We're</v><v Roger Bingham>actually</v><v Roger Bingham>at</v><v Roger Bingham>the</v><v Roger Bingham>Lucern</v><v Roger Bingham>Hotel,</v>\n<v Roger Bingham>just</v><v Roger Bingham>down</v><v Roger Bingham>the</v><v Roger Bingham>street</v><v Roger Bingham>from</v><v Roger Bingham>the</v>"

      assert "<v Roger Bingham>We're actually at the Lucern Hotel,</v>\n<v Roger Bingham>just down the street from the</v>" ==
               Payload.unmarshal!(input)
               |> Payload.simplify()
               |> Payload.marshal!()
    end
  end
end
