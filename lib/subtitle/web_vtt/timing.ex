defmodule Subtitle.WebVTT.Timing do
  # Timings appear in one of the two formats
  # mm:ss.ttt
  # hh:mm:ss.ttt
  #
  # Not using Time.from_iso8601!/1 as WebVTT supports up to 9999 hours in the
  # hour field.
  def parse(timing) do
    with [rest, raw_ttt] <- String.split(timing, ".", parts: 2),
         raw_rest_list = String.split(rest, ":"),
         {:ok, values} <- parse_integers(raw_rest_list ++ [raw_ttt]) do
      case values do
        [mm, ss, ttt] ->
          {:ok, to_ms(0, mm, ss, ttt)}

        [hh, mm, ss, ttt] ->
          {:ok, to_ms(hh, mm, ss, ttt)}

        _other ->
          :error
      end
    else
      _other ->
        :error
    end
  end

  def to_ms(mm, ss, ttt) do
    to_ms(0, mm, ss, ttt)
  end

  def to_ms(hh, mm, ss, ttt) do
    ttt + ss * 1_000 + mm * 60 * 1000 + hh * 60 * 60 * 1000
  end

  def from_ms(_ms) do
    "0000:00:00.1234"
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
