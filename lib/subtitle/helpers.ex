defmodule Subtitle.Helpers do
  def parse_integers(strings) do
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

  def to_ms(mm, ss, ttt) do
    to_ms(0, mm, ss, ttt)
  end

  def to_ms(hh, mm, ss, ttt) do
    ttt + ss * 1_000 + mm * 60 * 1000 + hh * 60 * 60 * 1000
  end

  def split_ms(ms) do
    hours = div(ms, 60 * 60 * 1000)
    mm = div(ms, 60 * 1000) - hours * 60
    ss = div(ms, 1000) - mm * 60 - hours * 60 * 60
    ttt = ms - ss * 1000 - mm * 60 * 1000 - hours * 60 * 60 * 1000
    [hours, mm, ss, ttt]
  end
end
