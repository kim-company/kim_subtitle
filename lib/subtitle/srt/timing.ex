defmodule Subtitle.SRT.Timing do
  alias Subtitle.Helpers

  # Timings appear in the format
  # hours:minutes:seconds,milliseconds (00:00:00,000) 
  def parse(timing) do
    with [rest, raw_ttt] <- String.split(timing, ",", parts: 2),
         raw_rest_list = String.split(rest, ":"),
         {:ok, [hh, mm, ss, ttt]} <- Helpers.parse_integers(raw_rest_list ++ [raw_ttt]) do
      {:ok, Helpers.to_ms(hh, mm, ss, ttt)}
    else
      _ ->
        :error
    end
  end

  def from_ms(ms) do
    [hours, mm, ss, ttt] =
      ms
      |> Helpers.split_ms()
      |> Enum.map(&to_string/1)

    [hours, mm, ss] = Enum.map([hours, mm, ss], fn x -> String.pad_leading(x, 2, ["0"]) end)
    ttt = String.pad_leading(ttt, 3, ["0"])

    [hours, ":", mm, ":", ss, ",", ttt]
  end
end
