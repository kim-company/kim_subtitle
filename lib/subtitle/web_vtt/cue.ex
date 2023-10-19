defmodule Subtitle.WebVTT.Cue do
  alias Subtitle.WebVTT.Payload

  defstruct [:from, :to, :payload, id: ""]

  @type t :: %__MODULE__{
          from: pos_integer(),
          to: pos_integer(),
          payload: Payload.t()
        }
end
