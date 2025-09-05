defmodule Subtitle.SRT do
  alias Subtitle.SRT.Timing
  alias Subtitle.Cue

  require Logger

  defstruct cues: []

  def unmarshal(srt, _opts \\ []) do
    case parse_body(srt, []) do
      {:ok, cues} -> {:ok, %__MODULE__{cues: discard_empty(cues)}}
      {:partial, cues, _} -> {:ok, %__MODULE__{cues: discard_empty(cues)}}
      {:error, error} -> {:error, error}
    end
  end

  def marshal!(srt) do
    Enum.map_join(srt.cues, "\n\n", &marshal_cue/1)
  end

  def parse_body(body, acc \\ []) do
    case :re.split(body, "(?:\r?\n){2}", parts: 2) do
      [""] ->
        {:ok, Enum.reverse(acc)}

      [rest] ->
        case parse_block(rest) do
          {:ok, cue} ->
            {:ok, Enum.reverse([cue | acc])}

          {:error, _reason} ->
            {:partial, acc, rest}
        end

      [block, rest] ->
        case parse_block(block) do
          {:ok, cue} ->
            parse_body(rest, [cue | acc])

          {:error, reason} ->
            Logger.warning("Parse SRT block: #{inspect(reason)}")
            parse_body(rest, acc)
        end
    end
  end

  defp parse_block(candidate_cue) do
    # Happens when a cue with no text is processed before.
    candidate_cue = String.trim(candidate_cue)

    with {:ok, id, rest} <- parse_cue_id(candidate_cue),
         {:ok, from, to, rest} <- parse_timings(rest) do
      {:ok,
       %Cue{
         id: id,
         from: from,
         to: to,
         text: String.trim(rest)
       }}
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

  defp marshal_cue(cue) do
    from = Timing.from_ms(cue.from)
    to = Timing.from_ms(cue.to)
    timing_info = "#{from} --> #{to}"

    id =
      cond do
        cue.id == nil -> nil
        String.trim(cue.id) == "" -> nil
        true -> String.trim(cue.id)
      end

    [id, timing_info, cue.text]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  defp discard_empty(cues), do: Enum.reject(cues, & &1.text == "")
end
