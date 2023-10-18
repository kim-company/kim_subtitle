defmodule Subtitle.SRT do
  alias Subtitle.SRT.Timing
  alias Subtitle.Cue

  require Logger

  defstruct cues: []

  def unmarshal(srt, _opts \\ []) do
    srt = String.replace(srt, "\r", "")

    with {:ok, cues} <- parse_body(srt, []) do
      {:ok, %__MODULE__{cues: cues}}
    end
  end

  defp parse_body(body, acc) do
    case String.split(body, "\n\n", parts: 2) do
      [""] ->
        cues =
          acc
          # This parser allows empty cues, which are useless.
          |> Enum.filter(fn %Cue{text: x} -> x != "" end)
          |> Enum.reverse()

        {:ok, cues}

      [block | rest] ->
        acc =
          case parse_block(block) do
            {:ok, cue} ->
              [cue | acc]

            {:error, reason} ->
              Logger.warning("Parse SRT block: #{inspect(reason)}")
              acc
          end

        body = if rest != [], do: List.first(rest), else: ""
        parse_body(body, acc)
    end
  end

  defp parse_block(candidate_cue) do
    # Happens when a cue with no text is processed before.
    candidate_cue = String.trim_leading(candidate_cue)

    with {:ok, id, rest} <- parse_cue_id(candidate_cue),
         {:ok, from, to, rest} <- parse_timings(rest) do
      {:ok,
       %Cue{
         id: id,
         from: from,
         to: to,
         text: String.trim(rest)
       }}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_cue_id(cue) do
    case String.split(cue, "\n", parts: 2) do
      [""] ->
        {:error, :invalid_cue}

      [id_or_timing, body] ->
        if String.contains?(id_or_timing, "-->") do
          {:ok, "", cue}
        else
          {:ok, id_or_timing, body}
        end
    end
  end

  defp parse_timings(cue) do
    with [timings, body] <- split_timings_body_safe(cue),
         [raw_from, raw_to] <- String.split(timings, " --> ", parts: 2),
         {:ok, from} <- Timing.parse(raw_from),
         {:ok, to} <- Timing.parse(raw_to) do
      {:ok, from, to, body}
    else
      _ -> {:error, :invalid_timings}
    end
  end

  defp split_timings_body_safe(cue) do
    if String.contains?(cue, "\n") do
      String.split(cue, "\n", parts: 2)
    else
      [cue, ""]
    end
  end
end
