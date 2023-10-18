defmodule Subtitle.Cue do
  defstruct [:from, :to, :text, id: ""]

  @max_distance_ms 250

  @type t :: %__MODULE__{
          text: String.t(),
          id: String.t(),
          from: non_neg_integer(),
          to: pos_integer()
        }

  @type split_option ::
          {:min_length, pos_integer()}
          | {:max_length, pos_integer()}

  @type merge_option ::
          {:max_lines, pos_integer()}
          | {:max_duration, pos_integer()}

  @type to_paragraphs_option ::
          {:silence, pos_integer()}

  @doc """
  Creates a list of paragraphs obtained from the text of the cues.
  Merges together cues that have no silence in between. Silence
  is configurable through the `opts.silence` option, which defaults
  to 1ms.
  """
  @spec to_paragraphs([t()], [to_paragraphs_option()]) :: [String.t()]
  def to_paragraphs(cues, opts \\ []) do
    cues
    |> to_paragraphs_lazy(opts)
    |> Enum.to_list()
  end

  @doc """
  Lazy version of to_paragraphs/2.
  """
  @spec to_paragraphs_lazy(Enumerable.t(), Keyword.t()) :: Stream.t()
  def to_paragraphs_lazy(cues, opts \\ []) do
    opts = Keyword.validate!(opts, silence: 1)
    silence = Keyword.fetch!(opts, :silence)

    reducer = fn
      next, [] ->
        {[], [next]}

      next, acc = [prev | _] ->
        if next.from - prev.to > silence do
          {[acc], [next]}
        else
          {[], [next | acc]}
        end
    end

    cues
    |> Stream.transform(fn -> [] end, reducer, fn acc -> {[acc], []} end, fn _ -> :ok end)
    |> Stream.map(&Enum.map(&1, fn cue -> cue.text end))
    |> Stream.map(fn acc ->
      acc
      |> Enum.reverse()
      |> Enum.join(" ")
      |> String.replace("\n", " ")
      |> String.trim()
    end)
  end

  @doc """
  Merges two cues given the following conditions:
  * The number of lines do not exceed `opts.max_lines`
  * The distance between the two cues is less than `@max_distance_ms`.
  * The duration of the cues does not exceed `opts.max_duration`

  The cues must be sorted by time and should not overlap.
  """
  @spec merge(t(), t(), [merge_option()]) :: {:ok, t()} | {:error, atom()}
  def merge(cue1, cue2, opts \\ []) do
    opts = Keyword.validate!(opts, max_lines: 2, max_duration: 8000)
    cue1_lines = String.split(cue1.text, "\n")
    cue2_lines = String.split(cue2.text, "\n")

    cond do
      length(cue1_lines) + length(cue2_lines) > opts[:max_lines] ->
        {:error, :too_many_lines}

      cue2.from - cue1.to > @max_distance_ms ->
        {:error, :gap_too_big}

      cue2.to - cue1.from > opts[:max_duration] ->
        {:error, :max_duration_exceeded}

      true ->
        cue = %__MODULE__{
          text: Enum.join(cue1_lines ++ cue2_lines, "\n"),
          from: cue1.from,
          to: cue2.to
        }

        {:ok, cue}
    end
  end

  @doc "Returns the duration of the cue."
  @spec duration(t()) :: pos_integer()
  def duration(cue), do: cue.to - cue.from

  @doc "Splits a cue into multiple single-line cues."
  @spec split(t(), [split_option()]) :: [t()]
  def split(cue, opts \\ []) do
    opts = Keyword.validate!(opts, min_length: 10, max_length: 37)
    cue = Map.update!(cue, :text, &String.trim/1)

    cond do
      cue.text == "" ->
        []

      String.length(cue.text) <= opts[:max_length] ->
        [cue]

      true ->
        cue.text
        |> split_words()
        |> wrap_words(opts[:max_length])
        |> join_words(opts[:min_length], opts[:max_length])
        |> add_timings(cue.from, cue.to)
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

  @doc "Adds the timings to all the lines by calculating them."
  def add_timings(lines, from, to) do
    lines_with_weights =
      Enum.map(lines, fn line ->
        weight =
          line
          |> String.graphemes()
          |> Enum.reduce(0, fn
            char, sum when char in [".", ",", ";", ":", "!", "?"] -> sum + 9
            _char, sum -> sum + 1
          end)

        {line, weight}
      end)

    total_weight =
      lines_with_weights
      |> Enum.map(&elem(&1, 1))
      |> Enum.sum()

    weight_duration = (to - from) / total_weight

    lines_with_weights
    |> Enum.map_reduce(from, fn {line, weight}, s_from ->
      s_to = round(s_from + weight_duration * weight)

      {%__MODULE__{
         text: line,
         from: s_from,
         to: if(s_to == to, do: s_to, else: s_to - 1)
       }, s_to}
    end)
    |> elem(0)
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

  # A sentence is pretty if it has at least `min_length` chars,
  # or has at least two chars and ends with a special character listed above.
  defp pretty?(sentence, min_length) do
    String.length(sentence) >= min_length and String.match?(sentence, ~r/\w{2,}[.,;:!?]$/)
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
