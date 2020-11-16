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
    Slack.send(url, %{text: "Hello"})
    Slack.send(url, %{text: "1"})
    Slack.send(url, %{text: "2"})
    Slack.send(url, %{text: "3"})
    Slack.send(url, %{text: "4"})
    Slack.send(url, %{text: "5"})
    Slack.send(url, %{text: "6"})
    Slack.send(url, %{text: "7"})
    Slack.send(url, %{text: "8"})
    Slack.send(url, %{text: "9"})
    Slack.send(url, %{text: "10"})
    Slack.send(url, %{text: "High Priority!"}, :high_priority)
  end
end
