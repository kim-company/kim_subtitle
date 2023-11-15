defmodule Subtitle.Cue do
  @moduledoc """
  Cue manipulation. It is aware of WebVTT tags in the text field.
  """
  alias Subtitle.WebVTT.Payload

  defstruct [:from, :to, :text, id: ""]

  @max_distance_ms 250
  @match_trailing_splitter ~r/[\.\?\!]$/

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
  @spec to_paragraphs([t()], [to_paragraphs_option()]) :: [{:text | :speaker, String.t()}]
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
    opts = Keyword.validate!(opts, silence: 1_000)
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
    |> Stream.flat_map(fn cues ->
      cues
      |> Enum.reverse()
      |> Enum.flat_map(fn cue ->
        # FIXME
        # this calculation is very similar to the add_timigs stuff.
        tags_with_weight =
          cue.text
          |> Payload.unmarshal!()
          |> Enum.map(fn tag -> {tag, compute_text_timing_weight(tag.text)} end)

        total_weight =
          tags_with_weight
          |> Enum.map(&elem(&1, 1))
          |> Enum.sum()

        weight_duration = (cue.to - cue.from) / total_weight

        tags_with_weight
        |> Enum.map_reduce(cue.from, fn {tag, weight}, s_from ->
          s_to = round(s_from + weight_duration * weight)
          {{tag, %{from: s_from, to: s_to}}, s_to}
        end)
        |> elem(0)
        |> Enum.map(fn
          {tag = %Payload.Tag{type: :voice}, timing} ->
            {timing.from, tag.attribute, tag.text}

          {tag, timing} ->
            {timing.from, nil, tag.text}
        end)
      end)
      |> Enum.reject(fn {_, _, s} -> String.match?(s, ~r/^\s*$/) end)
      |> Enum.reduce([], fn
        {from, x, text}, [] -> [{from, x, text}]
        {_, x, text}, [{from, x, old_text} | rest] -> [{from, x, old_text <> " " <> text} | rest]
        elem, acc -> [elem | acc]
      end)
      |> Enum.reverse()
      |> Enum.flat_map(fn {from, speaker, sentences} ->
        text =
          sentences
          |> String.replace("\n", " ")
          |> String.replace(~r/\s+/, " ")
          |> String.trim()

        List.flatten([
          if(speaker != nil, do: [{:speaker, speaker, from}], else: []),
          [{:text, text}]
        ])
      end)
      |> Enum.filter(fn elem -> elem != "" end)
    end)
  end

  def to_records(cues) do
    cues
    |> Stream.flat_map(fn cue ->
      tags_with_weight =
        cue.text
        |> Payload.unmarshal!()
        |> Payload.fragment(1_000_000)
        |> Enum.filter(fn tag -> tag.type == :voice end)
        |> Enum.map(fn tag -> {tag, compute_text_timing_weight(tag.text)} end)

      total_weight =
        tags_with_weight
        |> Enum.map(&elem(&1, 1))
        |> Enum.sum()

      weight_duration = (cue.to - cue.from) / total_weight

      tags_with_weight
      |> Enum.map_reduce(cue.from, fn {tag, weight}, s_from ->
        s_to = round(s_from + weight_duration * weight)

        {%{
           from: s_from,
           to: s_to,
           text: tag.text,
           speaker: tag.attribute,
           is_eos: false,
           type: "pronunciation"
         }, s_to}
      end)
      |> elem(0)
      |> Enum.flat_map(fn record ->
        split_splitter_record(record)
      end)
    end)
    |> Enum.into([])
  end

  defp split_splitter_record(record) do
    if String.match?(record.text, @match_trailing_splitter) do
      [text, punct] =
        Regex.split(@match_trailing_splitter, record.text, include_captures: true, trim: true)

      [
        %{record | to: record.to - 1, text: text},
        %{
          from: record.to - 1,
          to: record.to,
          text: punct,
          is_eos: true,
          speaker: record.speaker,
          type: "punctuation"
        }
      ]
    else
      [record]
    end
  end

  @doc "Splits a cue into multiple single-line cues."
  @spec split(t(), [split_option()]) :: [t()]
  def split(cue, opts \\ []) do
    opts = Keyword.validate!(opts, min_length: 10, max_length: 37)
    cue = Map.update!(cue, :text, &String.trim/1)

    tags = Payload.unmarshal!(cue.text)
    size = Payload.string(tags) |> String.length()

    cond do
      tags == [] ->
        []

      size <= opts[:max_length] ->
        [cue]

      true ->
        tags
        |> Payload.fragment(opts[:max_length])
        |> Payload.merge(opts[:min_length], opts[:max_length])
        |> add_timings(cue.from, cue.to)
    end
  end

  @doc """
  Merges two cues given the following conditions:
  * The number of lines do not exceed `opts.max_lines`
  * The distance between the two cues is less than `@max_distance_ms`.
  * The duration of the cues does not exceed `opts.max_duration`

  The cues must be sorted by time, should not overlap and should
  not contain new lines.
  """
  @spec merge(t(), t(), [merge_option()]) :: {:ok, t()} | {:error, atom()}
  def merge(cue1, cue2, opts \\ []) do
    opts = Keyword.validate!(opts, max_lines: 2, max_duration: 8000)

    [nlines1, nlines2] =
      Enum.map([cue1, cue2], fn cue ->
        cue.text
        |> Payload.unmarshal!()
        |> Payload.string()
        |> String.split("\n")
        |> Enum.count()
      end)

    cond do
      nlines1 + nlines2 > opts[:max_lines] ->
        {:error, :too_many_lines}

      cue2.from - cue1.to > @max_distance_ms ->
        {:error, :gap_too_big}

      cue2.to - cue1.from > opts[:max_duration] ->
        {:error, :max_duration_exceeded}

      true ->
        payload =
          [cue1, cue2]
          |> Enum.map(fn cue ->
            cue.text
            |> Payload.unmarshal!()
            |> Payload.marshal!()
          end)
          |> Enum.join("\n")

        cue = %__MODULE__{
          text: payload,
          from: cue1.from,
          to: cue2.to
        }

        {:ok, cue}
    end
  end

  @doc "Returns the duration of the cue."
  @spec duration(t()) :: pos_integer()
  def duration(cue), do: cue.to - cue.from

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

  defp compute_text_timing_weight(text) do
    text
    |> String.graphemes()
    |> Enum.reduce(0, fn
      char, sum when char in [".", ",", ";", ":", "!", "?"] -> sum + 9
      _char, sum -> sum + 1
    end)
  end

  defp add_timings(tags_batch, from, to) do
    # NOTE
    # Takes a batch of tags that come from the same original cue.
    # It is required that the whole batch is provided so to
    # correctly compute the time weigth of each line. Might not
    # be required with we preserve timing information with the
    # timing Tag.

    lines_with_weights =
      tags_batch
      |> Enum.map(fn tags ->
        line = Payload.string(tags)
        weight = compute_text_timing_weight(line)

        {Payload.marshal!(tags), weight}
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
end
