defmodule Subtitle.WebVTT do
  @moduledoc """
  https://developer.mozilla.org/en-US/docs/Web/API/WebVTT_API

  Web Video Text Tracks Format (WebVTT) is a format for displaying timed text
  tracks (such as subtitles or captions) using the <track> element. The primary
  purpose of WebVTT files is to add text overlays to a <video>. WebVTT is a
  text based format, which must be encoded using UTF-8. Where you can use
  spaces you can also use tabs. There is also a small API available to
  represent and manage these tracks and the data needed to perform the playback
  of the text at the correct times.
  """

  defstruct cues: [], header: %{}

  defmodule Note do
    defstruct [:text]
  end

  defmodule Style do
    defstruct [:css]
  end

  def mime(), do: "text/vtt"

  def unmarshal(vtt) do
    with {:ok, header, body} <- parse_header(vtt),
         offset = offset(header),
         {:ok, cues} <- parse_body(body, offset, []) do
      {:ok, %__MODULE__{cues: cues, header: header}}
    end
  end

  def unmarshal!(data) do
    case unmarshal(data) do
      {:ok, vtt} -> vtt
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def marshal(%__MODULE__{} = _vtt) do
    {:error, :not_implemented}
  end

  def marshal!(%__MODULE__{} = vtt) do
    case marshal(vtt) do
      {:ok, data} -> data
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  def timing_to_ms(mm, ss, ttt) do
    timing_to_ms(0, mm, ss, ttt)
  end

  def timing_to_ms(hh, mm, ss, ttt) do
    ttt + ss * 1_000 + mm * 60 * 1000 + hh * 60 * 60 * 1000
  end

  defp offset(%{offset: x}), do: x
  defp offset(_header), do: 0

  defp parse_header(vtt) do
    case String.split(vtt, "\n\n", parts: 2) do
      ["WEBVTT", body] ->
        {:ok, %{}, body}

      ["WEBVTT" <> text_header, body] ->
        header =
          text_header
          |> String.trim()
          |> String.split("\n")
          |> parse_header_fields(%{})

        {:ok, header, body}

      _other ->
        if is_invalid_empty_file?(vtt) do
          {:ok, %{}, ""}
        else
          {:error, :invalid_header, vtt}
        end
    end
  end

  defp parse_header_fields([], acc), do: acc

  defp parse_header_fields(["X-TIMESTAMP-MAP=" <> offsets | _], acc) do
    {offset, timestamp_map} =
      offsets
      |> String.split(",")
      |> Enum.map(&parse_offset/1)
      |> Enum.reduce(%{}, fn offset, acc ->
        Map.merge(acc, offset, fn :offset, v1, v2 -> v1 + v2 end)
      end)
      |> Map.pop!(:offset)

    acc
    |> Map.put(:offset, offset)
    |> Map.put(:x_timestamp_map, timestamp_map)
  end

  defp parse_header_fields([other | _], acc) do
    Map.update(acc, :description, [other], fn acc -> acc ++ [other] end)
  end

  defp parse_offset("MPEGTS:" <> amount) do
    timing = String.to_integer(amount)
    %{mpeg_ts: timing, offset: round(timing / 90)}
  end

  defp parse_offset("LOCAL:" <> amount) do
    {:ok, timing} = parse_timing(amount)
    %{local: timing, offset: -timing}
  end

  defp parse_offset(_), do: %{offset: 0}

  defp is_invalid_empty_file?(vtt) do
    vtt
    |> String.split("\n")
    |> Enum.member?("")
  end

  defp parse_body(body, offset, acc) do
    case String.split(body, "\n\n", parts: 2) do
      [""] ->
        {:ok, Enum.reverse(acc)}

      [block | rest] ->
        case parse_block(block, offset) do
          {:ok, cue_note_or_style} ->
            body = if rest != [], do: List.first(rest), else: ""
            parse_body(body, offset, [cue_note_or_style | acc])

          {:error, reason} ->
            {:error, reason, body}
        end
    end
  end

  defp parse_block("NOTE\n" <> text, _offset) do
    {:ok, %Note{text: String.trim(text)}}
  end

  defp parse_block("STYLE\n" <> css, _offset) do
    {:ok, %Style{css: String.trim(css)}}
  end

  defp parse_block(candidate_cue, offset) do
    {id, rest} = parse_cue_id(candidate_cue)

    case parse_timings(rest) do
      {:ok, from, to, rest} ->
        {:ok,
         %Subtitle.Cue{
           id: id,
           from: from + offset,
           to: to + offset,
           text: String.trim(rest)
         }}

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
          {"", cue}
        else
          {id_or_timing, body}
        end
    end
  end

  defp parse_timings(cue) do
    with [timings, body] <- String.split(cue, "\n", parts: 2),
         [raw_from, raw_to] <- String.split(timings, " --> ", parts: 2),
         {:ok, from} <- parse_timing(raw_from),
         {:ok, to} <- parse_timing(raw_to) do
      {:ok, from, to, body}
    else
      _ -> {:error, :invalid_timings}
    end
  end

  # Timings appear in one of the two formats
  # mm:ss.ttt
  # hh:mm:ss.ttt
  #
  # Not using Time.from_iso8601!/1 as WebVTT supports up to 9999 hours in the
  # hour field.
  defp parse_timing(timing) do
    with [rest, raw_ttt] <- String.split(timing, ".", parts: 2),
         raw_rest_list = String.split(rest, ":"),
         {:ok, values} <- parse_integers(raw_rest_list ++ [raw_ttt]) do
      case values do
        [mm, ss, ttt] ->
          {:ok, timing_to_ms(0, mm, ss, ttt)}

        [hh, mm, ss, ttt] ->
          {:ok, timing_to_ms(hh, mm, ss, ttt)}

        _other ->
          :error
      end
    else
      _other ->
        :error
    end
  end

  defp parse_integers(strings) do
    maybe_ints =
      strings
      |> Enum.map(&Integer.parse/1)
      |> Enum.map(fn
        {int, ""} ->
          int

        _other ->
          :error
      end)

    if Enum.member?(maybe_ints, :error) do
      :error
    else
      {:ok, maybe_ints}
    end
  end
end
