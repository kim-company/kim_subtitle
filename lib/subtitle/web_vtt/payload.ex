defmodule Subtitle.WebVTT.Payload do
  @type tag ::
          {:text, binary()}
          | {:bold, binary()}
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

  @doc "Returns the size of the text components of each tag"
  @spec text_size([tag()] | tag()) :: pos_integer()
  def text_size(tags) when is_list(tags) do
    tags
    |> text()
    |> String.length()
  end

  def text_size({_, text}), do: String.length(text)
  def text_size({_, _, text}), do: String.length(text)

  @doc "Extract text embedded in the tags"
  @spec text([tag()]) :: String.t()
  def text(tags) do
    tags
    |> Enum.reduce([], fn
      {_tag, text}, acc -> [text | acc]
      {_tag, _, text}, acc -> [text | acc]
    end)
    |> Enum.reverse()
    |> Enum.join(" ")
  end

  @doc "Splits each word in the text of the tags into a single tagged words"
  @spec split_words([tag()]) :: [tag()]
  def split_words(tags) do
    Enum.flat_map(tags, fn
      {tag, text} ->
        text
        |> String.split(" ", trim: true)
        |> Enum.map(fn word -> {tag, word} end)

      {tag, info, text} ->
        text
        |> String.split(" ", trim: true)
        |> Enum.map(fn word -> {tag, info, word} end)
    end)
  end

  @doc "Splits words when they are longer then the specified length"
  @spec wrap_words([tag()], pos_integer()) :: [tag()]
  def wrap_words(tags, _max_length) do
    # TODO
    # implement this one.
    # Enum.flat_map(words, &soft_wrap(&1, max_length))
    tags
  end

  # defp soft_wrap(word, max_length) do
  #   if String.length(word) <= max_length do
  #     [word]
  #   else
  #     case String.split(word, ["-", "–"], trim: true) do
  #       [word] -> hard_wrap(word, max_length)
  #       words -> Enum.flat_map(words, &soft_wrap("#{&1}-", max_length))
  #     end
  #   end
  # end

  # defp hard_wrap(word, max_length) do
  #   {pre, rest} = String.split_at(word, max_length - 1)
  #   ["#{pre}-" | soft_wrap(rest, max_length)]
  # end

  # A sentence is pretty if it has at least `min_length` chars,
  # or has at least two chars and ends with a special character listed above.
  @spec pretty?([tag()] | tag(), pos_integer()) :: boolean()
  def pretty?(tags, min_length) when is_list(tags) do
    text_size(tags) >= min_length and String.match?(text(tags), ~r/\w{2,}[.,;:!?]$/)
  end

  def pretty?(tag, min_length) do
    text =
      case tag do
        {_, text} -> text
        {_, _, text} -> text
      end

    String.length(text) >= min_length and String.match?(text, ~r/\w{2,}[.,;:!?]$/)
  end

  @spec join_words([tag()], pos_integer(), pos_integer()) :: [[tag()]]
  def join_words(tags, min_length, max_length) do
    tags
    |> join_words([], [], min_length, max_length)
    |> Enum.reverse()
  end

  # If we have a last and a prelast element we try to join them
  # in the case that the last one is to short and the prelast is not pretty.
  defp join_words([last], [prelast | acc], ready, min_length, _max_length) do
    if text_size(last) >= min_length or pretty?(prelast, min_length) do
      ([last, prelast | acc] ++ [ready])
      |> Enum.map(&Enum.reverse/1)
    else
      # In this case, we split the last buffer in half,
      # appending this tag to the second half.

      # NOTE
      # This could be improved by splitting on a character count basis instead of number of words.

      tags = split_words([last, prelast | acc])
      half = trunc(length(tags) / 2)

      last_two =
        tags
        |> Enum.split(half)
        |> Tuple.to_list()

      (last_two ++ ready)
      |> Enum.map(&Enum.reverse/1)
    end
  end

  defp join_words([last], [], [], _min_length, _max_length), do: [[last]]

  defp join_words([head | rest], buf, ready, min_length, max_length) do
    combined = [head | buf]

    if text_size(combined) > max_length or pretty?(head, min_length) do
      # In this case, we don't want to merge the two.
      join_words([head | rest], [], [buf | ready], min_length, max_length)
    else
      # Merge with buffer and go on!
      join_words(rest, [head | buf], ready, min_length, max_length)
    end
  end

  defp marshal_tag({:text, text}), do: text
  defp marshal_tag({:class, classname, text}), do: "<c." <> classname <> ">" <> text <> "</c>"
  defp marshal_tag({:voice, speaker, text}), do: "<v " <> speaker <> ">" <> text <> "</v>"
  defp marshal_tag({:bold, text}), do: "<b>" <> text <> "</b>"
  defp marshal_tag({:italics, text}), do: "<i>" <> text <> "</i>"
  defp marshal_tag({:underline, text}), do: "<u>" <> text <> "</u>"

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
