defmodule Subtitle.WebVTT.Timing do
  alias Subtitle.Helpers

  # Timings appear in one of the two formats
  # mm:ss.ttt
  # hh:mm:ss.ttt
  #
  # Not using Time.from_iso8601!/1 as WebVTT supports up to 9999 hours in the
  # hour field.
  def parse(timing) do
    with [rest, raw_ttt] <- String.split(timing, ".", parts: 2),
         raw_rest_list = String.split(rest, ":"),
         {:ok, values} <- Helpers.parse_integers(raw_rest_list ++ [raw_ttt]) do
      case values do
        [mm, ss, ttt] ->
          {:ok, Helpers.to_ms(0, mm, ss, ttt)}

        [hh, mm, ss, ttt] ->
          {:ok, Helpers.to_ms(hh, mm, ss, ttt)}

        _other ->
          :error
      end
    else
      _other ->
        :error
    end
  end

  def from_ms(ms) do
    [hours, mm, ss, ttt] = Helpers.split_ms(ms)

    hours_pad_size = if hours > 99, do: 4, else: 2
    [hours, mm, ss, ttt] = Enum.map([hours, mm, ss, ttt], &to_string/1)

    hours = String.pad_leading(hours, hours_pad_size, ["0"])
    [mm, ss] = Enum.map([mm, ss], fn x -> String.pad_leading(x, 2, ["0"]) end)
    ttt = String.pad_leading(ttt, 3, ["0"])

    [hours, ":", mm, ":", ss, ".", ttt]
  end
end
