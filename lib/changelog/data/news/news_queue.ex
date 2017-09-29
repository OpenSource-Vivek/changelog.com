defmodule Changelog.NewsQueue do
  use Changelog.Data

  require Logger

  alias Changelog.{NewsItem, NewsQueue}

  schema "news_queue" do
    field :position, :float
    belongs_to :item, NewsItem
  end

  def ordered(query \\ NewsQueue) do
    from i in query, order_by: [asc: :position]
  end

  def append(item) do
    entry = change(%NewsQueue{}, %{item_id: item.id})

    entries = Repo.all(NewsQueue.ordered)

    entry = if length(entries) > 0 do
      last_position = List.last(entries).position
      change(entry, %{position: last_position + 1.0})
    else
      change(entry, %{position: 1.0})
    end

    Repo.insert(entry)
  end

  def move(item = %NewsItem{}, to_index) do
    entry = Repo.get_by(NewsQueue, item_id: item.id)
    move(entry, to_index)
  end

  def move(entry = %NewsQueue{}, to_index) do
    entries = Repo.all(NewsQueue.ordered)
    current_index = Enum.find_index(entries, &(&1 == entry))

    entry = cond do
      to_index <= 0 -> # move to top
        first = List.first(entries)
        change(entry, %{position: first.position / 2})
      to_index >= (length(entries) - 1) -> # move to bottom
        last = List.last(entries)
        change(entry, %{position: last.position + 1})
      to_index < current_index -> # move up
        pre = Enum.at(entries, to_index - 1)
        post = Enum.at(entries, to_index)
        change(entry, %{position: (pre.position + post.position) / 2})
      to_index > current_index -> # move down
        pre = Enum.at(entries, to_index)
        post = Enum.at(entries, to_index + 1)
        change(entry, %{position: (pre.position + post.position) / 2})
      true -> change(entry, %{}) # no move-y
    end

    Repo.update(entry)
  end

  def preload_all(query = %Ecto.Query{}), do: Ecto.Query.preload(query, [item: :author])
  def preload_all(entry), do: Repo.preload(entry, [item: :author])

  def prepend(item) do
    entry = change(%NewsQueue{}, %{item_id: item.id})

    entries = NewsQueue.ordered |> Repo.all

    entry = if length(entries) > 0 do
      first_position = List.first(entries).position
      change(entry, %{position: first_position / 2})
    else
      change(entry, %{position: 1.0})
    end

    Repo.insert(entry)
  end

  def publish_next do
    case Repo.all(NewsQueue.ordered) do
      [entry | _rest] -> publish(entry)
      [] -> publish(nil)
    end
  end

  def publish(item = %NewsItem{}) do
    NewsQueue
    |> Repo.get_by(item_id: item.id)
    |> publish()
  end

  def publish(entry = %NewsQueue{}) do
    entry = Repo.preload(entry, :item)
    NewsItem.publish!(entry.item)
    Repo.delete!(entry)
    Logger.info("News: Published ##{entry.item.id}")
  end

  def publish(nil) do
    Logger.info("News: Published bupkis")
    false
  end
end
