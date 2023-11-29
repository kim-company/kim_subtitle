defmodule Subtitle.Cue.Builder do
  @moduledoc """
  Builder allows to format and align cues. Pass in unformatted, long sentenced cues
  and get back a stream of cues formatted with the provided defaults.

  Supports Cue payloads with WebVTT tags.
  """

  alias Subtitle.Cue

  defstruct [:pending, :last, :min_length, :max_length, :max_lines, :min_duration, :max_duration]

  @type t :: %__MODULE__{
          pending: Cue.t() | nil,
          min_length: non_neg_integer(),
          max_length: pos_integer(),
          min_duration: pos_integer(),
          max_duration: pos_integer(),
          max_lines: pos_integer()
        }

  @type new_option ::
          {:min_length, non_neg_integer()}
          | {:max_length, pos_integer()}
          | {:max_lines, pos_integer()}
          | {:min_duration, pos_integer()}
          | {:max_duration, pos_integer()}
  @spec new([new_option()]) :: t()
  def new(opts \\ []) do
    opts =
      Keyword.validate!(opts,
        min_length: 20,
        max_length: 37,
        min_duration: 2000,
        max_duration: 8000,
        max_lines: 2
      )

    %__MODULE__{
      pending: nil,
      last: nil,
      min_length: opts[:min_length],
      max_length: opts[:max_length],
      min_duration: opts[:min_duration],
      max_duration: opts[:max_duration],
      max_lines: opts[:max_lines]
    }
  end

  @doc "Adds a new cue and maybe returns built cues."
  @spec put_and_get(t(), Cue.t() | [Cue.t()], Keyword.t()) :: {t(), [Cue.t()]}
  def put_and_get(builder, cue_or_cues, opts \\ []) do
    flush = Keyword.get(opts, :flush, false)
    split_opts = [min_length: builder.min_length, max_length: builder.max_length]

    cues =
      cue_or_cues
      |> List.wrap()
      |> Enum.flat_map(&Cue.split(&1, split_opts))

    cues = if builder.pending, do: [builder.pending | cues], else: cues

    merge_opts = [max_lines: builder.max_lines, max_duration: builder.max_duration]
    cues = merge_cues(cues, merge_opts)

    {pending, done} =
      unless flush do
        [pending | done] = cues
        {pending, done}
      else
        {nil, cues}
      end

    cues = Enum.reverse(done)
    cues = finalize_cues(builder, cues)

    builder = %{
      builder
      | pending: pending,
        last: List.last(cues, builder.last)
    }

    {builder, cues}
  end

  @doc "Flushes the pending cue."
  @spec flush(t()) :: {t(), Cue.t() | nil}
  def flush(builder) when builder.pending == nil, do: {builder, nil}

  def flush(builder) do
    [cue] = finalize_cues(builder, [builder.pending])
    builder = %{builder | pending: nil, last: cue}
    {builder, cue}
  end

  @spec merge_cues([Cue.t()], [Cue.merge_option()]) :: [Cue.t()]
  defp merge_cues([], _opts), do: []

  defp merge_cues(cues, opts) when cues != [] do
    cues
    |> tl()
    |> Enum.reduce([hd(cues)], fn next, [cur | done] ->
      case Cue.merge(cur, next, opts) do
        {:ok, cue} ->
          [cue | done]

        {:error, _error} ->
          [next, cur | done]
      end
    end)
  end

  @spec finalize_cues(t(), [Cue.t()]) :: [Cue.t()]
  defp finalize_cues(builder, cues) do
    cues =
      cues
      |> Enum.map(&Cue.cut(&1, builder.max_duration))
      |> Enum.map(&Cue.extend(&1, builder.min_duration))

    if builder.last do
      [builder.last | cues]
      |> Cue.align()
      |> tl()
    else
      Cue.align(cues)
    end
  end
end
