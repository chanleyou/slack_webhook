defmodule SlackTest do
  use ExUnit.Case
  doctest Slack

  test "webhook" do
    url = Application.fetch_env!(:slack, :url)
    assert Slack.webhook(url, %{text: "Hello!"}) == :success
    assert Slack.webhook(url, %{ab: 1}) == :bad_request
    assert Slack.webhook('abc', %{}) == :failure
  end

  test "rate limit webhook" do
    url = Application.fetch_env!(:slack, :url)
    Slack.start_link()
    assert Slack.add_message(url, %{text: "1"}) == :success
    assert Slack.add_message(url, %{text: "2"}) == :success
    assert Slack.add_message(url, %{text: "3"}) == :success
    assert Slack.add_message(url, %{text: "4"}) == :success
    assert Slack.add_message(url, %{text: "5"}) == :success
  end
end
