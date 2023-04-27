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
    [pending | lines] = builder.pending
    put_line_opts = [max_lines: builder.max_lines, max_duration: builder.max_duration]

    %{done: done, pending: pending} =
      Enum.reduce(lines, %{done: [], pending: pending}, fn line, state ->
        case Cue.merge(state.pending, line, put_line_opts) do
          {:ok, cue} ->
            %{state | pending: cue}

          {:error, _error} ->
            %{state | pending: line, done: [state.pending | state.done]}
        end
      end)

    # TODO: Add some logic if the pending cue should be emitted or not.
    # Either its near to max duration, has reached the lines or maybe its already in the past.
    builder = %{builder | pending: pending}
    cues = Enum.reverse(done)

    {builder, cues}
  end

  # @doc "Flushes all pending lines and returns completed cues."
  # @spec flush(t()) :: {t(), [Cue.t()]}
  # def flush(builder) do
  #   # TODO
  #   {builder, []}
  # end
end
