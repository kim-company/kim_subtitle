defmodule Subtitle.WebVTT.Payload do
  alias Subtitle.WebVTT.Payload.Tag

  @spec unmarshal!(binary()) :: [Tag.t()]
  def unmarshal!(text) do
    case unmarshal(text) do
      {:ok, data} -> data
      {:error, reason, _text} -> raise ArgumentError, to_string(reason)
    end
  end

  @spec unmarshal(binary()) :: {:ok, [Tag.t()]} | {:error, binary()}
  def unmarshal(text) do
    tokens =
      text
      |> String.graphemes()
      |> tokenize([])

    case parse_tokens(tokens, nil, []) do
      {:ok, tags} -> {:ok, tags}
      {:error, reason} -> {:error, reason, text}
    end
  end

  @spec marshal!([Tag.t()]) :: binary()
  def marshal!(tags) do
    tags
    |> Enum.map(&marshal_tag/1)
    |> Enum.join("")
  end

  # A sentence is pretty if it has at least `min_length` chars,
  # or has at least two chars and ends with a special character listed above.
  @spec pretty?(binary(), pos_integer()) :: boolean()
  def pretty?(text, min_length) do
    String.length(text) >= min_length and String.match?(text, ~r/\w{2,}[.,;:!?]$/)
  end

  def string(tags) do
    tags
    |> List.wrap()
    |> Enum.map_join(" ", &to_string/1)
    |> String.replace(" \n ", "\n")
  end

  def size(tags) do
    tags
    |> string()
    |> String.length()
  end

  @doc """
  Merges equals tags together. Useful after a fragment call.
  """
  @spec simplify([Tag.t()]) :: [Tag.t()]
  def simplify(tags) do
    simplify(tags, [])
  end

  defp simplify([h | t], []), do: simplify(t, [h])
  defp simplify([], acc), do: Enum.reverse(acc)

  defp simplify([cur | t], [prev | acc]) do
    if Tag.equals(cur, prev) do
      simplify(t, [Tag.append_text(prev, cur.text) | acc])
    else
      simplify(t, [cur, prev | acc])
    end
  end

  @doc """
  Each tag will be fragmented into a list of single word tags of the same type. If words are longer than max_length, they are wrapped.
  """
  @spec fragment(Tag.t() | [Tag.t()], pos_integer()) :: [Tag.t()]
  def fragment(tag_or_tags, max_length) do
    tag_or_tags
    |> List.wrap()
    |> Enum.flat_map(fn tag ->
      tag.text
      |> String.split(~r/\s/, trim: true)
      |> wrap_words(max_length)
      |> Enum.map(fn word -> %Tag{tag | text: word} end)
    end)
  end

  @doc "Splits words when they are longer then the specified length"
  @spec wrap_words([binary()], pos_integer()) :: [binary()]
  def wrap_words(words, max_length) do
    Enum.flat_map(words, &soft_wrap(&1, max_length))
  end

  defp soft_wrap(word, max_length) do
    if String.length(word) <= max_length do
      [word]
    else
      case String.split(word, ["-", "–"], trim: true) do
        [word] -> hard_wrap(word, max_length)
        words -> Enum.flat_map(words, &soft_wrap("#{&1}-", max_length))
      end
    end
  end

  defp hard_wrap(word, max_length) do
    {pre, rest} = String.split_at(word, max_length - 1)
    ["#{pre}-" | soft_wrap(rest, max_length)]
  end

  @doc """
  Merges the tags until their text size falls within `min_length` and `max_length`. Calls simplify/1 on the final result.
  """
  @spec merge([Tag.t()], pos_integer(), pos_integer()) :: [[Tag.t()]]
  def merge(tags, min_length, max_length) do
    tags
    |> merge([], [], min_length, max_length)
    |> Enum.reverse()
    |> Enum.map(&simplify/1)
  end

  defp merge([cur], [], [], _min_length, _max_length), do: [[cur]]

  defp merge([], [single], ready, min_length, max_length) do
    last_line =
      hd(ready)
      |> Enum.reverse()
      |> string()

    if size(single) > min_length or pretty?(last_line, min_length) do
      [[single] | ready]
      |> Enum.map(&Enum.reverse/1)
    else
      # In this case, we split the last buffer in half,
      # appending this tag to the second half.

      # NOTE
      # This could be improved by splitting on a character count basis instead of number of words.

      tags = fragment([single | hd(ready)], max_length)
      # We're ceiling because the list is reversed and we prefer
      # the first (here the last)
      half = ceil(length(tags) / 2)

      last_two =
        tags
        |> Enum.split(half)
        |> Tuple.to_list()

      (last_two ++ tl(ready))
      |> Enum.map(&Enum.reverse/1)
    end
  end

  defp merge([], buf, ready, _min_length, _max_length) do
    [buf | ready]
    |> Enum.map(&Enum.reverse/1)
  end

  defp merge([cur | rest], buf, ready, min_length, max_length) do
    combined = [cur | buf]

    if size(combined) > max_length or pretty?(cur.text, min_length) do
      if buf == [] do
        # In this case, `cur` is a complete cue by itself.
        merge(rest, [], [[cur] | ready], min_length, max_length)
      else
        # In this case, we don't want to merge the two.
        merge([cur | rest], [], [buf | ready], min_length, max_length)
      end
    else
      # Merge with buffer and go on!
      merge(rest, [cur | buf], ready, min_length, max_length)
    end
  end

  defp marshal_tag(%Tag{type: :text, text: text}), do: text
  defp marshal_tag(%Tag{type: :bold, text: text}), do: "<b>" <> text <> "</b>"
  defp marshal_tag(%Tag{type: :italics, text: text}), do: "<i>" <> text <> "</i>"
  defp marshal_tag(%Tag{type: :underline, text: text}), do: "<u>" <> text <> "</u>"

  defp marshal_tag(%Tag{type: :class, attribute: classname, text: text}),
    do: "<c." <> classname <> ">" <> text <> "</c>"

  defp marshal_tag(%Tag{type: :voice, attribute: speaker, text: text}),
    do: "<v " <> speaker <> ">" <> text <> "</v>"

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
    {:ok, Enum.reverse(acc)}
  end

  defp parse_tokens([{:tag, "/" <> _tag} | t], nil, acc) do
    # This is a closing tag but we've already completed the
    # parsing of the current tag's contents, we can skip it.
    parse_tokens(t, nil, acc)
  end

  defp parse_tokens([{:tag, "c." <> classname} | t], nil, acc) do
    parse_tokens(t, Tag.class(classname, nil), acc)
  end

  defp parse_tokens([{:tag, "i"} | t], nil, acc) do
    parse_tokens(t, Tag.italics(nil), acc)
  end

  defp parse_tokens([{:tag, "b"} | t], nil, acc) do
    parse_tokens(t, Tag.bold(nil), acc)
  end

  defp parse_tokens([{:tag, "u"} | t], nil, acc) do
    parse_tokens(t, Tag.underline(nil), acc)
  end

  defp parse_tokens([{:tag, "v " <> name} | t], nil, acc) do
    parse_tokens(t, Tag.voice(name, nil), acc)
  end

  # Remove unknown tags
  defp parse_tokens([{:tag, _unknown} | t], nil, acc) do
    parse_tokens(t, nil, acc)
  end

  defp parse_tokens([{:text, text} | t], nil, acc) do
    parse_tokens(t, nil, [Tag.text(text) | acc])
  end

  defp parse_tokens([{:text, text} | t], tag, acc) do
    parse_tokens(t, nil, [Tag.update_text(tag, fn _ -> text end) | acc])
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
