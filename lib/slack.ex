defmodule Slack do
  use GenServer
  @name __MODULE__

  def start_link do
    GenServer.start_link(@name, {:queue.new(), :queue.new()}, name: Slack)
  end

  def init(q) do
    {:ok, q}
  end

  def send(url, body, opts \\ []) do
    priority =
      case Keyword.get(opts, :priority) do
        :high -> :high
        _ -> :normal
      end

    GenServer.cast(@name, {:add, %{url: url, body: body, priority: priority}})
  end

  def handle_cast({:add, item}, {priority, normal}) do
    new_state =
      case item.priority do
        :high -> {:queue.in(item, priority), normal}
        _ -> {priority, :queue.in(item, normal)}
      end

    if :queue.peek(priority) == :empty && :queue.peek(normal) == :empty do
      Process.send(@name, :webhook, [])
    end

    {:noreply, new_state}
  end

  def handle_info(:webhook, {priority, normal}) do
    queue_message(state)
  end

  defp queue_message({priority, normal}) do
    case handle_queue(priority) do
      {:ok, priority} ->
        {:noreply, {priority, normal}}

      :empty ->
        case handle_queue(normal) do
          {:ok, normal} -> {:noreply, {priority, normal}}
          _ -> {:noreply, {priority, normal}}
        end

      _ ->
        {:noreply, {priority, normal}}
    end
  end

  defp handle_queue(queue) do
    case :queue.out(queue) do
      {{:value, head}, rest} ->
        case webhook(head.url, head.body) do
          :ok ->
            Process.send(@name, :webhook, [])
            {:ok, rest}

          {:wait, seconds} ->
            Process.send_after(@name, :webhook, seconds * 1000)
            {:ok, queue}

          # todo: error handling
          _ ->
            {:fail, queue}
        end

      {:empty, _} ->
        :empty
    end
  end

  defp webhook(url, body) do
    case :httpc.request(:post, {url, [], 'application/json', Jason.encode!(body)}, [], []) do
      {:ok, {{_, code, _}, headers, _}} ->
        case code do
          200 ->
            :ok

          429 ->
            {_, timeout} = Enum.find(headers, fn h -> elem(h, 0) == 'retry-after' end)
            {seconds, _} = :string.to_integer(timeout)
            {:wait, seconds}

          # malformed JSON or something
          400 ->
            :bad_request

          _ ->
            :fail
        end

      _ ->
        :fail
    end
  end
end
