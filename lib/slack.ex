defmodule Slack do
  use GenServer

  def init(q) do
    {:ok, q}
  end

  def handle_cast({:webhook}, [priority_queue, normal_queue]) do
    case :queue.out(priority_queue) do
      {{:value, head}, new_priority_queue} ->
        webhook(head.url, head.body)

        if :queue.len(new_priority_queue) + :queue.len(normal_queue) > 0 do
          :timer.sleep(1000)
          GenServer.cast(MyQueues, {:webhook})
        end

        {:noreply, [new_priority_queue, normal_queue]}

      {:empty, _} ->
        case :queue.out(normal_queue) do
          {{:value, head}, new_normal_queue} ->
            webhook(head.url, head.body)

            if :queue.len(new_normal_queue) > 0 do
              :timer.sleep(1000)
              GenServer.cast(MyQueues, {:webhook})
            end

            {:noreply, [priority_queue, new_normal_queue]}

          # do nothing
          {:empty, empty_queue} ->
            {:noreply, [priority_queue, empty_queue]}
        end
    end
  end

  def handle_cast({:add, item}, [priority_queue, normal_queue]) do
    new_state =
      if item.priority == :high,
        do: [:queue.in(item, priority_queue), normal_queue],
        else: [priority_queue, :queue.in(item, normal_queue)]

    [new_p, new_n] = new_state

    if :queue.len(new_p) + :queue.len(new_n) > 0 do
      GenServer.cast(MyQueues, {:webhook})
    end

    {:noreply, new_state}
  end

  def handle_info({:ok}, state) do
    IO.puts(state)
    {:noreply, state}
  end

  def start do
    GenServer.start_link(__MODULE__, [:queue.new(), :queue.new()], name: MyQueues)
  end

  def send(url, body) do
    GenServer.cast(MyQueues, {:add, %{url: url, body: body, priority: :normal}})
  end

  def send(url, body, :high_priority) do
    GenServer.cast(MyQueues, {:add, %{url: url, body: body, priority: :high}})
  end

  defp webhook(url, body) do
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
