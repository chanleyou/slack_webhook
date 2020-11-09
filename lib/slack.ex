defmodule Slack do
  use Agent

  def start_link do
    Agent.start_link(fn -> :queue.new() end, name: __MODULE__)
  end

  defp add_to_queue(url, body) do
    Agent.update(__MODULE__, fn q -> :queue.in(%{url: url, body: body}, q) end)
  end

  defp get_head do
    Agent.get(__MODULE__, fn q ->
      {{:value, head}, _} = :queue.out(q)
      head
    end)
  end

  defp remove_head do
    Agent.update(__MODULE__, fn q ->
      {_, new_queue} = :queue.out(q)
      new_queue
    end)
  end

  defp get_length do
    Agent.get(__MODULE__, fn q -> :queue.len(q) end)
  end

  def add_message(url, body) do
    add_to_queue(url, body)

    if get_length() == 1 do
      rate_limit()
    end
  end

  def rate_limit do
    if get_length() > 0 do
      item = get_head()

      case webhook(item.url, item.body) do
        :success ->
          :timer.sleep(1000)
          remove_head()
          rate_limit()
          :success

        # error code 429 supposedly triggers a 30 second timeout in Slack documentation
        :too_many_requests ->
          :timer.sleep(30000)
          rate_limit()

        # malformed json or something
        :bad_request -> 
          remove_head()
          rate_limit()
          :bad_request

        other ->
          other
      end
    end
  end

  def webhook(url, body) do
    case :httpc.request(:post, {url, [], 'application/json', Jason.encode!(body)}, [], []) do
      {:ok, {{_, code, _}, _, _}} ->
        case code do
          200 -> :success
          400 -> :bad_request
          429 -> :too_many_requests
          _ -> :failure
        end

      _ ->
        :failure
    end
  end
end
