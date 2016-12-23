defmodule Crontab.CronDateChecker do
  import Crontab.CronInterval

  @moduledoc """
  This Module is used to check a Crontab.CronInterval against a given date.
  """

  @doc """
  Check a Crontab.CronInterval against a given date.

  ### Examples
    iex> Crontab.CronDateChecker.matches_date :hour, [{:"/", :*, 4}, 7], ~N[2004-04-16 04:07:08]
    true

    iex> Crontab.CronDateChecker.matches_date :hour, [8], ~N[2004-04-16 04:07:08]
    false

    iex> Crontab.CronDateChecker.matches_date %Crontab.CronInterval{minute: [{:"/", :*, 8}]}, ~N[2004-04-16 04:08:08]
    true

    iex> Crontab.CronDateChecker.matches_date %Crontab.CronInterval{minute: [{:"/", :*, 9}]}, ~N[2004-04-16 04:07:08]
    false
  """
  def matches_date(_, [:* | _], _), do: true
  def matches_date(_, [], _), do: false
  def matches_date(interval, [condition | tail], execution_date) do
    values = get_interval_value(interval, execution_date)
    if matches_specific_date(interval, values, condition, execution_date) do
      true
    else
      matches_date(interval, tail, execution_date)
    end
  end
  def matches_date(cron_interval = %Crontab.CronInterval{}, execution_date) do
    cron_interval
      |> to_condition_list
      |> matches_date(execution_date)
  end
  def matches_date([], _), do: true
  def matches_date([{interval, conditions} | tail], execution_date) do
    matches_date(interval, conditions, execution_date) && matches_date(tail, execution_date)
  end

  defp matches_specific_date(_, [], _, _), do: false
  defp matches_specific_date(_, _, :*, _), do: true
  defp matches_specific_date(interval, [head_value | tail_values], condition = {:-, from, to}, execution_date) do
    cond do
      from > to && (head_value >= from || head_value <= to) -> true
      from <= to && head_value >= from && head_value <= to -> true
      true -> matches_specific_date(interval, tail_values, condition, execution_date)
    end
  end
  defp matches_specific_date(:weekday, [0 | tail_values], condition = {:/, _, _}, execution_date) do
    matches_specific_date(:weekday, tail_values, condition, execution_date)
  end
  defp matches_specific_date(interval, values = [head_value | tail_values], condition = {:/, base = {:-, from, _}, divider}, execution_date) do
    if matches_specific_date(interval, values, base, execution_date) && rem(head_value - from, divider) == 0 do
      true
    else
      matches_specific_date(interval, tail_values, condition, execution_date)
    end
  end
  defp matches_specific_date(:day, [head_value | tail_values], :L, execution_date) do
    if Timex.end_of_month(execution_date).day == head_value do
      true
    else
      matches_specific_date(:day, tail_values, :L, execution_date)
    end
  end
  defp matches_specific_date(:weekday, _, {:L, weekday}, execution_date) do
    last_weekday(execution_date, weekday) == execution_date.day
  end
  defp matches_specific_date(:weekday, _, {:"#", weekday, n}, execution_date) do
    nth_weekday(execution_date, weekday, n) == execution_date.day
  end
  defp matches_specific_date(interval, values = [head_value | tail_values], condition = {:/, base, divider}, execution_date) do
    if matches_specific_date(interval, values, base, execution_date) && rem(head_value, divider) == 0 do
      true
    else
      matches_specific_date(interval, tail_values, condition, execution_date)
    end
  end
  defp matches_specific_date(interval, [head_value | tail_values], number, execution_date) when is_integer(number) do
    if head_value == number do
      true
    else
      matches_specific_date(interval, tail_values, number, execution_date)
    end
  end

  defp last_weekday(date, weekday) do
    date
      |> Timex.end_of_month
      |> last_weekday(weekday, :end)
  end
  defp last_weekday(date = %NaiveDateTime{year: year, month: month, day: day}, weekday, :end) do
    if :calendar.day_of_the_week(year, month, day) == weekday do
      day
    else
      last_weekday(Timex.shift(date, days: -1), weekday, :end)
    end
  end

  defp nth_weekday(date, weekday, n) do
    date
      |> Timex.beginning_of_month
      |> nth_weekday(weekday, n, :start)
  end
  defp nth_weekday(date = %NaiveDateTime{}, _, 0, :start), do: Timex.shift(date, days: -1).day
  defp nth_weekday(date = %NaiveDateTime{year: year, month: month, day: day}, weekday, n, :start) do
    if :calendar.day_of_the_week(year, month, day) == weekday do
      nth_weekday(Timex.shift(date, days: 1), weekday, n - 1, :start)
    else
      nth_weekday(Timex.shift(date, days: 1), weekday, n, :start)
    end
  end

  defp get_interval_value(:minute, %NaiveDateTime{minute: minute}), do: [minute]
  defp get_interval_value(:hour, %NaiveDateTime{hour: hour}), do: [hour]
  defp get_interval_value(:day, %NaiveDateTime{day: day}), do: [day]
  defp get_interval_value(:weekday, %NaiveDateTime{year: year, month: month, day: day}) do
    day = :calendar.day_of_the_week(year, month, day)
    if day == 7 do
      [0, 7]
    else
      [day]
    end
  end
  defp get_interval_value(:month, %NaiveDateTime{month: month}), do: [month]
  defp get_interval_value(:year, %NaiveDateTime{year: year}), do: [year]
end
