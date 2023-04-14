defmodule Subtitle.Cue do
  defstruct [:from, :to, :text, id: ""]

  @type t :: %__MODULE__{
          text: String.t(),
          id: String.t(),
          from: non_neg_integer(),
          to: pos_integer()
        }

  @type split_option ::
          {:min_length, pos_integer()}
          | {:max_length, pos_integer()}

  @doc "Returns the duration of the cue."
  @spec duration(t()) :: pos_integer()
  def duration(cue), do: cue.to - cue.from

  @doc "Splits a cue into multiple single-line cues."
  @spec split(t(), [split_option()]) :: [t()]
  def split(cue, opts \\ []) do
    opts = Keyword.validate!(opts, min_length: 10, max_length: 37)

    if String.length(cue.text) <= opts[:max_length] do
      [cue]
    else
      cue.text
      |> split_words()
      |> wrap_words(opts[:max_length])
      |> join_words(opts[:min_length], opts[:max_length])
      |> build_lines(cue.from, cue.to)
    end
  end

  @doc """
  Extend cue to last at least `min_duration`.
  May produce overlapping cues that can be fixed by calling `__MODULE__.align/1`.
  """
  @spec extend(t(), non_neg_integer()) :: t()
  def extend(cue, min_duration) do
    if duration(cue) < min_duration do
      %{cue | to: cue.from + min_duration}
    else
      cue
    end
  end

  @doc """
  Cuts the duration to at most `max_duration`.
  """
  @spec cut(t(), pos_integer()) :: t()
  def cut(cue, max_duration) do
    if duration(cue) > max_duration do
      %{cue | to: cue.from + max_duration}
    else
      cue
    end
  end

  @doc """
  Transforms cue into a temporarily ordered sequence of cues,
  preserving their duration. It adds 1ms between overapping cues.
  """
  @spec align([t()]) :: [t()]
  def align(cues) do
    if length(cues) > 1 do
      {prev, next} = Enum.split(cues, 1)
      do_align(next, prev)
    else
      cues
    end
  end

  defp do_align([], acc), do: Enum.reverse(acc)

  defp do_align([right | rest], [left | acc]) do
    if left.to >= right.from do
      from = left.to + 1
      to = from + duration(right)
      right = %{right | from: from, to: to}

      do_align(rest, [right, left | acc])
    else
      do_align(rest, [right, left | acc])
    end
  end

  @doc """
  Removes overlapping cues.
  This function is useful after merging HLS segments, as a cue might be repeated in multiple segments.
  """
  @spec tidy([t()]) :: [t()]
  def tidy(cues)
  def tidy([]), do: []

  def tidy(cues) do
    cues
    |> Enum.chunk_by(fn %__MODULE__{text: text} -> text end)
    |> Enum.map(fn
      [cue] ->
        cue

      chunk ->
        id =
          chunk
          |> Enum.map(fn %__MODULE__{id: x} -> x end)
          |> Enum.filter(fn id -> id != "" and id != nil end)
          |> Enum.join("-")

        %__MODULE__{from: from, text: text} = List.first(chunk)
        %__MODULE__{to: to} = List.last(chunk)
        %__MODULE__{id: id, from: from, to: to, text: text}
    end)
  end

  defp split_words(sentence) do
    String.split(sentence, " ", trim: true)
  end

  defp wrap_words(words, max_length) do
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

  defp build_lines(lines, from, to) do
    chars = Enum.reduce(lines, 0, fn line, total -> String.length(line) + total end)
    char_duration = (to - from) / chars

    lines
    |> Enum.map_reduce(0, fn line, s_from ->
      s_to = round(s_from + char_duration * String.length(line))

      {%__MODULE__{
         text: line,
         from: s_from,
         to: if(s_to == to, do: s_to, else: s_to - 1)
       }, s_to}
    end)
    |> elem(0)
  end

  # A sentence is pretty if it has at least `min_length` chars,
  # or has at least two chars and ends with a special character listed above.
  defp pretty?(sentence, min_length) do
    String.length(sentence) >= min_length ||
      String.match?(sentence, ~r/\w{2,}[.,;:!?]$/)
  end

  defp join_words(words, min_length, max_length) do
    words
    |> join_words([], min_length, max_length)
    |> Enum.reverse()
  end

  # If we have a last and a prelast element we try to join them
  # in the case that the last one is to short and the prelast is not pretty.
  defp join_words([last], [prelast | acc], min_length, _max_length) do
    if String.length(last) >= min_length or pretty?(prelast, min_length) do
      [last, prelast | acc]
    else
      # NOTE: This could be improved by splitting on a character count basis instead of number of words.
      words = split_words("#{prelast} #{last}")
      half = trunc(length(words) / 2)

      words
      |> Enum.split(half)
      |> Tuple.to_list()
      |> Enum.map(&Enum.join(&1, " "))
      |> Enum.reverse()
      |> Enum.concat(acc)
    end
  end

  defp join_words([last], [], _min_length, _max_length), do: [last]

  defp join_words([first, second | rest], acc, min_length, max_length) do
    combined = "#{first} #{second}"

    if String.length(combined) > max_length or pretty?(first, min_length) do
      join_words([second | rest], [first | acc], min_length, max_length)
    else
      join_words([combined | rest], acc, min_length, max_length)
    end
  end
end
