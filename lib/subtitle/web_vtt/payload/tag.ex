defmodule Subtitle.WebVTT.Payload.Tag do
  @type type :: :text | :bold | :italics | :underline | :voice | :class | :time

  @type t :: %__MODULE__{type: type(), text: binary(), attribute: any()}
  defstruct [:type, :text, :attribute]

  defimpl String.Chars do
    def to_string(t) do
      t.text
    end
  end

  def class(name, text), do: %__MODULE__{type: :class, attribute: name, text: text}
  def voice(name, text), do: %__MODULE__{type: :voice, attribute: name, text: text}
  def text(text), do: %__MODULE__{type: :text, text: text}
  def bold(text), do: %__MODULE__{type: :bold, text: text}
  def italics(text), do: %__MODULE__{type: :italics, text: text}
  def underline(text), do: %__MODULE__{type: :underline, text: text}

  def update_text(tag, fun) do
    %__MODULE__{tag | text: fun.(tag.text) |> String.replace(~r/\s*\n\s*/, "\n")}
  end

  def append_text(tag, new_text) do
    update_text(tag, fn old ->
      "#{old} #{new_text}"
    end)
  end

  def equals(left, right) do
    left.type == right.type and left.attribute == right.attribute
  end
end
