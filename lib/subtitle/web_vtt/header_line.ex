defmodule Subtitle.WebVTT.HeaderLine do
  defstruct [:key, :original, :data]

  def new(line = "X-TIMESTAMP-MAP=" <> offsets) do
    offset =
      offsets
      |> String.split(",")
      |> Enum.map(&parse_offset/1)
      |> Enum.sum()

    %__MODULE__{key: :x_timestamp_map, original: line, data: %{offset: offset}}
  end

  def new(line) do
    %__MODULE__{key: :description, original: line, data: %{}}
  end

  defp parse_offset("MPEGTS:" <> amount) do
    timing =
      amount
      |> String.trim()
      |> String.to_integer()

    round(timing / 90)
  end

  defp parse_offset("LOCAL:" <> amount) do
    {:ok, timing} =
      amount
      |> String.trim()
      |> Subtitle.WebVTT.Timing.parse()

    -timing
  end
end
