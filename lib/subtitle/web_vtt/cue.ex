defmodule Subtitle.WebVTT.Cue do
  def new(from, to, payload) when is_binary(payload) do
    %Subtitle.Cue{from: from, to: to, text: payload}
  end

  def new(from, to, payload) when is_list(payload) do
    %Subtitle.Cue{from: from, to: to, text: Subtitle.WebVTT.Payload.marshal!(payload)}
  end
end
