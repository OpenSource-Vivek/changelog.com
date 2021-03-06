defmodule Changelog.UrlKit do
  alias Changelog.NewsSource

  def get_html(url) when is_nil(url), do: ""
  def get_html(url) do
    case HTTPoison.get!(url, [], [follow_redirect: true, max_redirect: 5]) do
      %{status_code: 200, headers: headers, body: body} ->
        case List.keyfind(headers, "Content-Encoding", 0) do
          {"Content-Encoding", "gzip"} -> :zlib.gunzip(body)
          {"Content-Encoding", "x-gzip"} -> :zlib.gunzip(body)
          _else -> body
        end
      _else -> ""
    end
  end

  def get_source(url) when is_nil(url), do: nil
  def get_source(url) do
    NewsSource.get_by_url(url)
  end

  def get_title(url) when is_nil(url), do: nil
  def get_title(url) do
    url |> get_html |> extract_title
  end

  def extract_title(html) do
    case Regex.named_captures(~r/<title.*?>(?<title>.*?)<\/title>/s, html) do
      %{"title" => title} -> title |> String.trim() |> String.split("\n") |> List.first
      _else -> "Couldn't parse title. Report to Jerod!"
    end
  end

  def get_type(url) when is_nil(url), do: :link
  def get_type(url) do
    cond do
      Enum.any?(project_regexes(), fn(r) -> Regex.match?(r, url) end) -> :project
      Enum.any?(video_regexes(), fn(r) -> Regex.match?(r, url) end) -> :video
      true -> :link
    end
  end

  def normalize_url(url) when is_nil(url), do: nil
  def normalize_url(url) do
    parsed = URI.parse(url)
    query = normalize_query_string(parsed.query)

    parsed
    |> Map.put(:query, query)
    |> URI.to_string()
  end

  defp normalize_query_string(query) when is_nil(query), do: nil
  defp normalize_query_string(query) do
    normalized =
      query
      |> URI.decode_query()
      |> Map.drop(~w(utm_source utm_campaign utm_medium utm_term utm_content))
      |> URI.encode_query()

    if String.length(normalized) == 0 do
      nil
    else
      normalized
    end
  end

  defp project_regexes do
    [
      ~r/github\.com(?!\/blog)/,
      ~r/(?<!about\.)gitlab\.com/
    ]
  end

  defp video_regexes do
    [
      ~r/youtube\.com\/watch/,
      ~r/vimeo\.com\/\d+/,
      ~r/go\.twitch\.tv\/videos/
    ]
  end
end
