defmodule Subtitle.WebVTT.Payload do
  @type tag ::
          {:bold, binary()}
          | {:italics, binary()}
          | {:underline, binary()}
          | {:voice, speaker :: binary(), binary()}
          | {:class, name :: binary(), binary()}

  @spec unmarshal!(binary()) :: [tag()]
  def unmarshal!(text) do
    case unmarshal(text) do
      {:ok, data} -> data
      {:error, reason, _text} -> raise ArgumentError, to_string(reason)
    end
  end

  @spec unmarshal!(binary()) :: {:ok, [tag()]} | {:error, binary()}
  def unmarshal(text) do
    tokens =
      text
      |> String.graphemes()
      |> tokenize([])

    parse_tokens(tokens, nil, [])
  end

  @spec marshal!([tag()]) :: binary()
  def marshal!(tags) do
    tags
    |> Enum.map(&marshal_tag/1)
    |> Enum.join("")
  end

  def marshal_tag({:text, text}), do: text
  def marshal_tag({:class, classname, text}), do: "<c." <> classname <> ">" <> text <> "</c>"
  def marshal_tag({:voice, speaker, text}), do: "<v " <> speaker <> ">" <> text <> "</v>"
  def marshal_tag({:bold, text}), do: "<b>" <> text <> "</b>"
  def marshal_tag({:italics, text}), do: "<i>" <> text <> "</i>"
  def marshal_tag({:underline, text}), do: "<u>" <> text <> "</u>"

  defp tokenize([], acc) do
    Enum.reverse(acc)
  end

  defp tokenize(["<" | rest], acc) do
    {tag, rest} = consume_graphemes(rest, ">", [])
    tokenize(rest, [{:tag, Enum.join(tag)} | acc])
  end

  defp tokenize(rest, acc) do
    {text, rest} = consume_graphemes(rest, "<", [])
    # In case there is still some data in rest, it means we
    # stopped at <. Restore it to enable correct parsing of
    # the next tag.
    rest = if length(rest) > 0, do: ["<" | rest], else: rest
    tokenize(rest, [{:text, Enum.join(text)} | acc])
  end

  defp parse_tokens([], nil, acc) do
    # FIXME
    # Finalize parsing of the current tag in case it
    # was not closed.
    {:ok, Enum.reverse(acc)}
  end

  defp parse_tokens([{:tag, "/" <> _tag} | t], nil, acc) do
    # This is a closing tag but we've already completed the
    # parsing of the current tag's contents, we can skip it.
    parse_tokens(t, nil, acc)
  end

  defp parse_tokens([{:tag, "c." <> classname} | t], nil, acc) do
    parse_tokens(t, {:class, classname, nil}, acc)
  end

  defp parse_tokens([{:tag, "i"} | t], nil, acc) do
    parse_tokens(t, {:italics, nil}, acc)
  end

  defp parse_tokens([{:tag, "b"} | t], nil, acc) do
    parse_tokens(t, {:bold, nil}, acc)
  end

  defp parse_tokens([{:tag, "u"} | t], nil, acc) do
    parse_tokens(t, {:underline, nil}, acc)
  end

  defp parse_tokens([{:tag, "v " <> name} | t], nil, acc) do
    parse_tokens(t, {:voice, name, nil}, acc)
  end

  defp parse_tokens([{:text, text} | t], nil, acc) do
    parse_tokens(t, nil, [{:text, text} | acc])
  end

  defp parse_tokens([{:text, text} | t], {tag, name, nil}, acc) when tag in [:class, :voice] do
    parse_tokens(t, nil, [{tag, name, text} | acc])
  end

  defp parse_tokens([{:text, text} | t], {tag, nil}, acc)
       when tag in [:italics, :bold, :underline] do
    parse_tokens(t, nil, [{tag, text} | acc])
  end

  defp consume_graphemes([next | rest], ending, acc) when next == ending do
    # discard the ending character
    {Enum.reverse(acc), rest}
  end

  defp consume_graphemes([], _ending, acc) do
    # We reached the end and we allow the parser to let this be
    # as if the tag was actually closed.
    {Enum.reverse(acc), []}
  end

  defp consume_graphemes([next | rest], ending, acc) do
    consume_graphemes(rest, ending, [next | acc])
  end
end
