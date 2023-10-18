defmodule Subtitle.WebVTT.PayloadTest do
  use ExUnit.Case
  alias Subtitle.WebVTT.Payload

  describe "unmarshal!/1" do
    # https://developer.mozilla.org/en-US/docs/Web/API/Payload_API#vttcue

    test "w/o tags" do
      assert [{:text, "text"}] = Payload.unmarshal!("text")
    end

    test "w/ class tag" do
      assert [{:class, "classname", "text"}] = Payload.unmarshal!("<c.classname>text</c>")
    end

    test "w/ italics tag" do
      assert [{:italics, "text"}] = Payload.unmarshal!("<i>text</i>")
    end

    test "w/ bold tag" do
      assert [{:bold, "text"}] = Payload.unmarshal!("<b>text</b>")
    end

    test "w/ underline tag" do
      assert [{:underline, "text"}] = Payload.unmarshal!("<u>text</u>")
    end

    @tag skip: true
    test "w/ ruby/text tag" do
      assert [{:ruby, [{:rt, "WWW", "World Wide Web"}, {:rt, "oui", "yes"}]}] =
               Payload.unmarshal!("<ruby>WWW<rt>World Wide Web</rt>oui<rt>yes</rt></ruby>")
    end

    test "w/ voice tag" do
      assert [{:voice, "Bob", "text"}] = Payload.unmarshal!("<v Bob>text</v>")
    end
  end

  describe "marshal!/1" do
    test "w/o tags" do
      input = [{:text, "text"}]
      assert ^input = Payload.marshal!(input) |> Payload.unmarshal!()
    end

    test "w/ class tag" do
      input = [{:class, "classname", "text"}]
      assert ^input = Payload.marshal!(input) |> Payload.unmarshal!()
    end

    test "w/ italics tag" do
      input = [{:italics, "text"}]
      assert ^input = Payload.marshal!(input) |> Payload.unmarshal!()
    end

    test "w/ bold tag" do
      input = [{:bold, "text"}]
      assert ^input = Payload.marshal!(input) |> Payload.unmarshal!()
    end

    test "w/ underline tag" do
      input = [{:underline, "text"}]
      assert ^input = Payload.marshal!(input) |> Payload.unmarshal!()
    end

    test "w/ voice tag" do
      input = [{:voice, "Bob", "text"}]
      assert ^input = Payload.marshal!(input) |> Payload.unmarshal!()
    end
  end
end
