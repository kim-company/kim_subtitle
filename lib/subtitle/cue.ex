defmodule Subtitle.Cue do
  defstruct [:from, :to, :text, id: ""]

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
          |> Enum.join(" - ")

        %__MODULE__{from: from, text: text} = List.first(chunk)
        %__MODULE__{to: to} = List.last(chunk)
        %__MODULE__{id: id, from: from, to: to, text: text}
    end)
  end
end
