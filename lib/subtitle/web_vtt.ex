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

  require Logger

  alias Subtitle.WebVTT.{Timing, Note, Style, HeaderLine}
  alias Subtitle.Cue

  defstruct header: [], cues: []

  def mime(), do: "text/vtt"

  def unmarshal(vtt, opts \\ []) do
    vtt = String.replace(vtt, "\r", "")
    add_offset? = Keyword.get(opts, :add_offset?, true)

    with {:ok, header, body} <- split_header_body(vtt),
         header = parse_header(header),
         offset = if(add_offset?, do: cue_offset(header), else: 0),
         {:ok, cues} <- parse_body(body, offset, []) do
      {:ok, %__MODULE__{header: header, cues: cues}}
    end
  end

  def unmarshal!(data, opts \\ []) do
    case unmarshal(data, opts) do
      {:ok, vtt} -> vtt
      {:error, reason, _vtt} -> raise ArgumentError, to_string(reason)
    end
  end

  def marshal!(%__MODULE__{} = vtt) do
    header = marshal_header(vtt)
    body = marshal_body(vtt)
    splitter = if body != [], do: ["\n"], else: []
    ending = if body != [], do: [], else: ["\n"]
    IO.iodata_to_binary([header, splitter, body, ending])
  end

  defp marshal_header(%__MODULE__{header: header}) do
    Enum.map(header, fn %HeaderLine{original: original} -> [original, "\n"] end)
  end

  defp marshal_body(%__MODULE__{header: header, cues: cues}) do
    offset = cue_offset(header)

    cues
    |> Enum.map(fn cue = %Cue{from: from, to: to} ->
      %Cue{cue | from: from - offset, to: to - offset}
    end)
    |> Enum.map(fn %Cue{id: id, from: from, to: to, text: text} ->
      id = if id != "" and id != nil, do: [id, "\n"], else: []
      [id, Timing.from_ms(from), " --> ", Timing.from_ms(to), "\n", text, "\n\n"]
    end)
  end

  defp parse_header(header) do
    header
    |> String.trim()
    |> String.split("\n")
    |> Enum.map(&HeaderLine.new/1)
  end

  defp split_header_body(vtt) do
    case String.split(vtt, "\n\n", parts: 2) do
      [header = "WEBVTT" <> _rest, body] ->
        {:ok, header, body}

      _other ->
        if is_invalid_empty_file?(vtt) do
          {:ok, "WEBVTT", ""}
        else
          {:error, :invalid_header, vtt}
        end
    end
  end

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
         %Cue{
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
         {:ok, from} <- Timing.parse(raw_from),
         {:ok, to} <- Timing.parse(raw_to) do
      {:ok, from, to, body}
    else
      _ -> {:error, :invalid_timings}
    end
  end

  defp cue_offset(header) do
    timestamp_map = Enum.find(header, fn %HeaderLine{key: key} -> key == :x_timestamp_map end)

    case timestamp_map do
      %HeaderLine{data: %{offset: x}} -> x
      _other -> 0
    end
  end
end
