defmodule Subtitle.Cue.Builder do
  alias Subtitle.Cue

  defstruct [:pending, :min_length, :max_length, :max_lines, :min_duration, :max_duration]

  @type t :: %__MODULE__{
          pending: [Cue.t()],
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
      pending: [],
      min_length: opts[:min_length],
      max_length: opts[:max_length],
      min_duration: opts[:min_duration],
      max_duration: opts[:max_duration],
      max_lines: opts[:max_lines]
    }
  end

  @doc "Adds a new sentence and maybe returns built cues."
  @spec put(t(), Cue.t()) :: t()
  def put(builder, cue) do
    lines = Cue.split(cue)
    Map.update!(builder, :pending, &Enum.concat(&1, lines))
  end

  @doc "Builds the cues based on the lines in the buffer."
  @spec build_cues(t()) :: {t(), [Cue.t()]}
  def build_cues(%{pending: []} = builder), do: {builder, []}

  def build_cues(builder) do
    put_line_opts = [max_lines: builder.max_lines, max_duration: builder.max_duration]

    [pending | done] =
      builder.pending
      |> tl()
      |> Enum.reduce([hd(builder.pending)], fn next, [cur | done] ->
        case Cue.merge(cur, next, put_line_opts) do
          {:ok, cue} ->
            [cue | done]

          {:error, _error} ->
            [next, cur | done]
        end
      end)

    # TODO: Add some logic if the pending cue should be emitted right away or not.
    # Either its near to max duration, has reached the lines or maybe its already in the past.
    builder = %{builder | pending: [pending]}
    {builder, Enum.reverse(done)}
  end

  @doc "Flushes the pending cue."
  # @spec flush(t()) :: {t(), Cue.t() | nil}
  # def flush(builder) do
  #   {builder, builder.pending}
  # end
end
