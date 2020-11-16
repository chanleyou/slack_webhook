defmodule Slack do
  use GenServer
  @name __MODULE__

  def init(q) do
    {:ok, q}
  end

  def start_link do
    GenServer.start_link(@name, {:queue.new(), :queue.new()}, name: Slack)
  end

  def handle_cast({:add, item}, {priority, normal}) do
    new_state =
      case item.priority do
        :high -> {:queue.in(item, priority), normal}
        _ -> {priority, :queue.in(item, normal)}
      end

    {new_priority, new_normal} = new_state

    if :queue.len(new_priority) + :queue.len(new_normal) == 1 do
      Process.send(@name, :webhook, [])
    end

    {:noreply, new_state}
  end

  def handle_info(:webhook, state) do
    queue_message(state)
  end

  def send(url, body) do
    GenServer.cast(@name, {:add, %{url: url, body: body, priority: :normal}})
  end

  def send(url, body, :high_priority) do
    GenServer.cast(@name, {:add, %{url: url, body: body, priority: :high}})
  end

  defp queue_message({priority, normal}) do
    case :queue.out(priority) do
      {{:value, head}, new_priority} ->
        case webhook(head.url, head.body) do
          :success ->
            if :queue.len(new_priority) > 0 || :queue.len(normal) > 0 do
              Process.send_after(@name, :webhook, 1000)
            end

            {:noreply, {new_priority, normal}}

          {:too_many_requests, seconds} ->
            Process.send_after(@name, :webhook, seconds * 1000)
            {:noreply, {priority, normal}}

          # todo: other error handling
          _ ->
            {:noreply, {priority, normal}}
        end

      {:empty, _} ->
        case :queue.out(normal) do
          {{:value, head}, new_normal} ->
            case webhook(head.url, head.body) do
              :success ->
                if :queue.len(new_normal) > 0 do
                  Process.send_after(@name, :webhook, 1000)
                end

                {:noreply, {priority, new_normal}}

              {:too_many_requests, seconds} ->
                Process.send_after(@name, :webhook, seconds * 1000)
                {:noreply, {priority, normal}}

              _ ->
                {:noreply, {priority, normal}}
            end

          # do nothing
          {:empty, empty_queue} ->
            {:noreply, {priority, empty_queue}}
        end
    end
  end

  defp webhook(url, body) do
    case :httpc.request(:post, {url, [], 'application/json', Jason.encode!(body)}, [], []) do
      {:ok, {{_, code, _}, headers, _}} ->
        case code do
          200 ->
            :success

          # malformed JSON or something
          400 ->
            :bad_request

          429 ->
            {_(timeout)} = Enum.find(headers, fn h -> elem(h, 0) == 'retry-after' end)
            {seconds, _} = Integer.parse(to_string(timeout))
            {:too_many_requests, seconds}

          _ ->
            :failure
        end

      _ ->
        :failure
    end
  end
end
