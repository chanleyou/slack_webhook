defmodule SlackTest do
  use ExUnit.Case, async: true
  doctest Slack

  # test "webhook" do
  #   assert Slack.webhook(url, %{text: "Hello!"}) == :success
  #   assert Slack.webhook(url, %{ab: 1}) == :bad_request
  #   assert Slack.webhook('abc', %{}) == :failure
  # end

  # test "rate limit webhook" do
  # Slack.start_link()
  #   assert Slack.add_message(url, %{text: "1"}) == :success
  #   assert Slack.add_message(url, %{text: "2"}) == :success
  #   assert Slack.add_message(url, %{text: "3"}) == :success
  #   assert Slack.add_message(url, %{text: "4"}) == :success
  #   assert Slack.add_message(url, %{text: "5"}) == :success
  # end

  test "gen server" do
    url = Application.fetch_env!(:slack, :url)
    Slack.start_link()
    Slack.send(url, %{text: "Start!"})
    Slack.send(url, %{text: "1"})
    Slack.send(url, %{text: "2"})
    Slack.send(url, %{text: "3"})
    Slack.send(url, %{text: "4"})
    Slack.send(url, %{text: "5"})
    Slack.send(url, %{text: "High Priority!"}, priority: :high)

    # Enum.each(1..400, fn(x) -> IO.puts("Slack.send(url, %{text: \"" <> to_string(x) <> "\"})") end)
  end
end
