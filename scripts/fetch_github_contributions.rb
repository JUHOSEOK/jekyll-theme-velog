#!/usr/bin/env ruby

require "json"
require "net/http"
require "open3"
require "time"
require "uri"
require "yaml"
require "date"

ROOT_DIR = File.expand_path("..", __dir__)
CONFIG_PATH = File.join(ROOT_DIR, "_config.yml")
PROFILE_PATH = File.join(ROOT_DIR, "_data", "profile.yml")
THEME_PATH = File.join(ROOT_DIR, "_data", "theme.yml")
OUTPUT_PATH = File.join(ROOT_DIR, "_data", "github_contributions_cache.json")
PROFILE_OUTPUT_PATH = File.join(ROOT_DIR, "_data", "github_profile_cache.json")
PROFILES_OUTPUT_PATH = File.join(ROOT_DIR, "_data", "github_profiles_cache.json")
FAVICON_OUTPUT_PATH = File.join(ROOT_DIR, "assets", "images", "favicon.png")
GRAPHQL_ENDPOINT = URI("https://api.github.com/graphql")
REST_API_ENDPOINT = "https://api.github.com/users"
GRAPHQL_QUERY = <<~GRAPHQL
  query($login: String!, $from: DateTime!, $to: DateTime!) {
    user(login: $login) {
      contributionsCollection(from: $from, to: $to) {
        contributionCalendar {
          totalContributions
          weeks {
            contributionDays {
              contributionCount
              date
              weekday
            }
          }
        }
      }
    }
  }
GRAPHQL

def load_yaml(path)
  return {} unless File.exist?(path)

  YAML.safe_load(File.read(path), permitted_classes: [Date, Time], aliases: true) || {}
end

def load_json(path)
  return {} unless File.exist?(path)

  JSON.parse(File.read(path))
rescue JSON::ParserError
  {}
end

def write_payload(path, payload)
  File.write(path, "#{JSON.pretty_generate(payload)}\n")
end

def sync_favicon_png(avatar_url:, output_path:)
  return false if avatar_url.to_s.strip.empty?

  python_script = <<~PYTHON
    import sys
    import urllib.request
    from pathlib import Path

    try:
      from PIL import Image, ImageDraw
    except Exception:
      raise SystemExit(2)

    url = sys.argv[1]
    output = Path(sys.argv[2])
    tmp = output.with_suffix(".tmp.png")

    urllib.request.urlretrieve(url, tmp)

    try:
      image = Image.open(tmp).convert("RGBA").resize((256, 256), Image.Resampling.LANCZOS)
      mask = Image.new("L", (256, 256), 0)
      draw = ImageDraw.Draw(mask)
      draw.ellipse((12, 12, 244, 244), fill=255)

      canvas = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
      canvas.paste(image, (0, 0), mask)

      ring = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
      ring_draw = ImageDraw.Draw(ring)
      ring_draw.ellipse((12, 12, 244, 244), outline=(208, 215, 222, 255), width=4)
      canvas.alpha_composite(ring)

      output.parent.mkdir(parents=True, exist_ok=True)
      canvas.save(output)
    finally:
      if tmp.exists():
        tmp.unlink()
  PYTHON

  _stdout, _stderr, status = Open3.capture3("python3", "-c", python_script, avatar_url, output_path)
  status.success?
rescue Errno::ENOENT
  false
end

def gh_token
  stdout, status = Open3.capture2("gh", "auth", "token")
  return "" unless status.success?

  stdout.strip
rescue Errno::ENOENT
  ""
end

def placeholder_year_payload(year:, from_date:, to_date:, account_count:)
  {
    "year" => year,
    "from" => from_date.iso8601,
    "to" => to_date.iso8601,
    "range_label" => "#{from_date.strftime('%Y.%m.%d')} ~ #{to_date.strftime('%Y.%m.%d')}",
    "summary_label" => summary_label(year: year, total_contributions: 0, account_count: account_count),
    "total_contributions" => 0,
    "account_count" => account_count,
    "months" => [],
    "weeks" => []
  }
end

def placeholder_payload(title:, primary_login:, accounts:, reason:)
  {
    "enabled" => false,
    "title" => title,
    "login" => primary_login,
    "profile_url" => primary_login.to_s.empty? ? "" : "https://github.com/#{primary_login}",
    "accounts" => accounts,
    "account_graphs" => [],
    "available_years" => [],
    "years" => [],
    "reason" => reason,
    "weeks" => [],
    "months" => []
  }
end

def placeholder_profile_payload(login:, profile_url:, reason:)
  {
    "enabled" => false,
    "login" => login,
    "profile_url" => profile_url,
    "display_name" => "",
    "bio" => "",
    "intro" => "",
    "avatar_url" => "",
    "reason" => reason
  }
end

def profiles_payload(profiles:, reason:)
  {
    "enabled" => profiles.any? { |profile| profile["enabled"] },
    "profiles" => profiles,
    "reason" => reason
  }
end

def tooltip_label(date_string, contribution_count)
  date = Date.parse(date_string)
  "#{date.strftime('%Y년 %-m월 %-d일')} · #{contribution_count}회 기여"
end

def summary_label(year:, total_contributions:, account_count:)
  if account_count > 1
    "#{year}년 #{account_count}개 계정 합산 #{total_contributions}회 기여"
  else
    "#{year}년 #{total_contributions}회 기여"
  end
end

def strict_mode?
  ENV["GITHUB_CONTRIBUTIONS_STRICT"] == "1" || ENV.key?("CI") || ENV.key?("JENKINS_HOME")
end

def parse_login_from_github_url(value)
  value.to_s[%r{\Ahttps://github\.com/([^/?#]+)}, 1].to_s.strip
end

def resolve_usernames(settings:, profile:)
  explicit_primary = settings["username"].to_s.strip
  fallback_login = parse_login_from_github_url(profile["github"])
  if fallback_login.empty?
    fallback_login = Array(profile["accounts"])
      .map { |account| account["login"].to_s.strip.empty? ? parse_login_from_github_url(account["github"]) : account["login"].to_s.strip }
      .reject(&:empty?)
      .first.to_s
  end
  primary_login = explicit_primary.empty? ? fallback_login : explicit_primary

  configured_usernames = Array(settings["usernames"])
    .map { |value| value.to_s.strip }
    .reject(&:empty?)
  configured_usernames.concat(
    Array(profile["accounts"])
      .map { |account| account["login"].to_s.strip.empty? ? parse_login_from_github_url(account["github"]) : account["login"].to_s.strip }
      .reject(&:empty?)
  )

  usernames = configured_usernames.dup
  usernames.unshift(primary_login) unless primary_login.empty?
  usernames.uniq!

  [primary_login, usernames]
end

def fetch_github_profile(login:, profile_url:, token:)
  uri = URI("#{REST_API_ENDPOINT}/#{login}")
  request = Net::HTTP::Get.new(uri)
  request["Accept"] = "application/vnd.github+json"
  request["User-Agent"] = "velog-jekyll-theme"
  request["Authorization"] = "Bearer #{token}" unless token.to_s.empty?

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  response = http.request(request)

  return placeholder_profile_payload(login: login, profile_url: profile_url, reason: "request_failed") unless response.is_a?(Net::HTTPSuccess)

  body = JSON.parse(response.body)
  display_name = body["name"].to_s.strip
  display_name = login if display_name.empty?

  intro_parts = [body["company"], body["location"], body["blog"]]
    .map { |value| value.to_s.strip }
    .reject(&:empty?)

  {
    "enabled" => true,
    "login" => login,
    "profile_url" => body["html_url"].to_s.strip.empty? ? profile_url : body["html_url"].to_s.strip,
    "display_name" => display_name,
    "bio" => body["bio"].to_s.strip,
    "intro" => intro_parts.join(" · "),
    "avatar_url" => body["avatar_url"].to_s.strip,
    "reason" => ""
  }
rescue JSON::ParserError
  placeholder_profile_payload(login: login, profile_url: profile_url, reason: "invalid_response")
end

def build_year_ranges(year_count:, now:)
  current_year = now.year

  Array.new(year_count) do |index|
    year = current_year - index
    from_date = Date.new(year, 1, 1)
    to_date = Date.new(year, 12, 31)

    {
      year: year,
      from_date: from_date,
      to_date: to_date,
      from_time: Time.new(from_date.year, from_date.month, from_date.day, 0, 0, 0, now.utc_offset),
      to_time: year == current_year ? now : Time.new(to_date.year, to_date.month, to_date.day, 23, 59, 59, now.utc_offset)
    }
  end
end

def fetch_contribution_calendar(login:, from_time:, to_time:, token:)
  request = Net::HTTP::Post.new(GRAPHQL_ENDPOINT)
  request["Authorization"] = "bearer #{token}"
  request["Content-Type"] = "application/json"
  request["User-Agent"] = "velog-jekyll-theme"
  request.body = JSON.generate(
    {
      query: GRAPHQL_QUERY,
      variables: {
        login: login,
        from: from_time.iso8601,
        to: to_time.iso8601
      }
    }
  )

  http = Net::HTTP.new(GRAPHQL_ENDPOINT.host, GRAPHQL_ENDPOINT.port)
  http.use_ssl = true
  response = http.request(request)

  return [nil, "request_failed_#{response.code}"] unless response.is_a?(Net::HTTPSuccess)

  body = JSON.parse(response.body)
  return [nil, "graphql_error"] if body["errors"]

  calendar = body.dig("data", "user", "contributionsCollection", "contributionCalendar")
  return [nil, "missing_calendar"] if calendar.nil?

  [calendar, nil]
rescue JSON::ParserError
  [nil, "invalid_response"]
end

def build_date_counts(calendar)
  counts = Hash.new(0)

  calendar.fetch("weeks", []).each do |week|
    week.fetch("contributionDays", []).each do |day|
      counts[day.fetch("date")] += day.fetch("contributionCount").to_i
    end
  end

  counts
end

def contribution_level(count, max_count)
  return "NONE" if count <= 0 || max_count <= 0

  ratio = count.to_f / max_count
  return "FIRST_QUARTILE" if ratio <= 0.25
  return "SECOND_QUARTILE" if ratio <= 0.5
  return "THIRD_QUARTILE" if ratio <= 0.75

  "FOURTH_QUARTILE"
end

def build_months(start_date:, end_date:)
  months = []
  current_week = 1
  current_month = nil
  date = start_date

  while date <= end_date
    if date != start_date && date.wday.zero?
      current_week += 1
    end

    month_key = [date.year, date.month]
    if current_month.nil? || current_month[:key] != month_key
      if current_month
        current_month[:payload]["total_weeks"] = current_week - current_month[:payload]["start_week"]
        months << current_month[:payload]
      end

      current_month = {
        key: month_key,
        payload: {
          "label" => "#{date.month}월",
          "start_week" => current_week,
          "total_weeks" => 1,
          "year" => date.year
        }
      }
    end

    date += 1
  end

  if current_month
    current_month[:payload]["total_weeks"] = current_week - current_month[:payload]["start_week"] + 1
    months << current_month[:payload]
  end

  months
end

def build_weeks(start_date:, end_date:, counts:)
  weeks = []
  week_start = start_date
  padded_days = Array.new(7) { { "is_padding" => true } }
  max_count = counts.values.max.to_i
  date = start_date

  while date <= end_date
    if date != start_date && date.wday.zero?
      weeks << { "first_day" => week_start.iso8601, "days" => padded_days }
      week_start = date
      padded_days = Array.new(7) { { "is_padding" => true } }
    end

    date_string = date.iso8601
    count = counts.fetch(date_string, 0)
    padded_days[date.wday] = {
      "is_padding" => false,
      "date" => date_string,
      "count" => count,
      "level" => contribution_level(count, max_count),
      "tooltip" => tooltip_label(date_string, count)
    }

    date += 1
  end

  weeks << { "first_day" => week_start.iso8601, "days" => padded_days }
  weeks
end

def build_year_payload(year_range:, calendars:, accounts:)
  aggregate_counts = Hash.new(0)
  total_contributions = 0

  calendars.each do |calendar|
    total_contributions += calendar.fetch("totalContributions").to_i
    build_date_counts(calendar).each do |date, count|
      aggregate_counts[date] += count
    end
  end

  {
    "year" => year_range.fetch(:year),
    "from" => year_range.fetch(:from_date).iso8601,
    "to" => year_range.fetch(:to_date).iso8601,
    "range_label" => "#{year_range.fetch(:from_date).strftime('%Y.%m.%d')} ~ #{year_range.fetch(:to_date).strftime('%Y.%m.%d')}",
    "summary_label" => summary_label(
      year: year_range.fetch(:year),
      total_contributions: total_contributions,
      account_count: accounts.size
    ),
    "total_contributions" => total_contributions,
    "account_count" => accounts.size,
    "accounts" => accounts,
    "months" => build_months(start_date: year_range.fetch(:from_date), end_date: year_range.fetch(:to_date)),
    "weeks" => build_weeks(
      start_date: year_range.fetch(:from_date),
      end_date: year_range.fetch(:to_date),
      counts: aggregate_counts
    )
  }
end

def enrich_payload_with_active_year(payload)
  active_year = payload["years"].find { |year_payload| year_payload["weeks"] && !year_payload["weeks"].empty? }
  active_year ||= payload["years"].first
  return payload if active_year.nil?

  payload.merge(
    "profile_url" => payload["login"].to_s.empty? ? "" : "https://github.com/#{payload['login']}",
    "range_label" => active_year["range_label"],
    "summary_label" => active_year["summary_label"],
    "total_contributions" => active_year["total_contributions"],
    "months" => active_year["months"],
    "weeks" => active_year["weeks"]
  )
end

def build_account_graph(login:, year_ranges:, token:)
  profile_url = "https://github.com/#{login}"
  years = []
  failures = []

  year_ranges.each do |year_range|
    calendar, reason = fetch_contribution_calendar(
      login: login,
      from_time: year_range.fetch(:from_time),
      to_time: year_range.fetch(:to_time),
      token: token
    )

    if calendar
      years << build_year_payload(
        year_range: year_range,
        calendars: [calendar],
        accounts: [{ "login" => login, "profile_url" => profile_url }]
      )
    else
      failures << { "login" => login, "year" => year_range.fetch(:year), "reason" => reason }
      years << placeholder_year_payload(
        year: year_range.fetch(:year),
        from_date: year_range.fetch(:from_date),
        to_date: year_range.fetch(:to_date),
        account_count: 1
      )
    end
  end

  graph = enrich_payload_with_active_year(
    {
      "login" => login,
      "profile_url" => profile_url,
      "available_years" => years.map { |year_payload| year_payload["year"] },
      "years" => years
    }
  )

  [graph, failures]
end

config = load_yaml(CONFIG_PATH)
profile = load_yaml(PROFILE_PATH)
theme = load_yaml(THEME_PATH)
settings = theme.dig("hero", "github_contributions") || {}
profile_sync_settings = theme.dig("profile", "github_sync") || {}
title = settings["title"].to_s.strip
title = "GitHub 기여 그래프" if title.empty?
enabled = settings.fetch("enabled", false)
profile_sync_enabled = profile_sync_settings.fetch("enabled", true)
years_to_fetch = settings["years"].to_i
years_to_fetch = 1 if years_to_fetch <= 0

ENV["TZ"] = config["timezone"].to_s unless config["timezone"].to_s.empty?

primary_login, logins = resolve_usernames(settings: settings, profile: profile)
profile_url = primary_login.empty? ? "" : "https://github.com/#{primary_login}"
accounts = logins.map { |login| { "login" => login, "profile_url" => "https://github.com/#{login}" } }

token = ENV["GITHUB_GRAPHQL_TOKEN"].to_s.strip
token = ENV["GITHUB_TOKEN"].to_s.strip if token.empty?
token = gh_token if token.empty?

if !profile_sync_enabled
  write_payload(
    PROFILE_OUTPUT_PATH,
    placeholder_profile_payload(login: primary_login, profile_url: profile_url, reason: "disabled")
  )
  write_payload(PROFILES_OUTPUT_PATH, profiles_payload(profiles: [], reason: "disabled"))
elsif primary_login.empty?
  write_payload(
    PROFILE_OUTPUT_PATH,
    placeholder_profile_payload(login: "", profile_url: "", reason: "missing_username")
  )
  write_payload(PROFILES_OUTPUT_PATH, profiles_payload(profiles: [], reason: "missing_username"))
else
  profile_payloads = logins.map do |login|
    fetch_github_profile(login: login, profile_url: "https://github.com/#{login}", token: token)
  end
  primary_profile_payload = profile_payloads.find { |payload| payload["login"] == primary_login } || profile_payloads.first

  write_payload(PROFILE_OUTPUT_PATH, primary_profile_payload)
  write_payload(PROFILES_OUTPUT_PATH, profiles_payload(profiles: profile_payloads, reason: ""))

  if primary_profile_payload["enabled"] && !primary_profile_payload["avatar_url"].to_s.strip.empty?
    sync_favicon_png(avatar_url: primary_profile_payload["avatar_url"], output_path: FAVICON_OUTPUT_PATH)
  end
end

unless enabled
  write_payload(
    OUTPUT_PATH,
    placeholder_payload(
      title: title,
      primary_login: primary_login,
      accounts: accounts,
      reason: "disabled"
    )
  )
  puts "GitHub contributions graph is disabled."
  exit 0
end

if logins.empty?
  payload = placeholder_payload(title: title, primary_login: "", accounts: [], reason: "missing_username")
  write_payload(OUTPUT_PATH, payload)
  abort "GitHub contributions usernames are missing." if strict_mode?
  puts "GitHub contributions usernames are missing. Skipping graph."
  exit 0
end

if token.empty?
  if File.exist?(OUTPUT_PATH)
    existing_payload = load_json(OUTPUT_PATH)
    if existing_payload.is_a?(Hash) && !existing_payload.empty?
      puts "GitHub token is missing. Keeping existing contributions cache."
      exit 0
    end
  end

  payload = placeholder_payload(title: title, primary_login: primary_login, accounts: accounts, reason: "missing_token")
  write_payload(OUTPUT_PATH, payload)
  abort "GitHub token is missing. Set GITHUB_GRAPHQL_TOKEN or log in with gh auth." if strict_mode?
  puts "GitHub token is missing. Skipping graph fetch."
  exit 0
end

now = Time.now
year_ranges = build_year_ranges(year_count: years_to_fetch, now: now)
account_graphs = []
failed_requests = []

logins.each do |login|
  account_graph, account_failures = build_account_graph(login: login, year_ranges: year_ranges, token: token)
  account_graphs << account_graph
  failed_requests.concat(account_failures)
end

if account_graphs.all? { |account_graph| account_graph["years"].all? { |year_payload| year_payload["weeks"].empty? } }
  payload = placeholder_payload(
    title: title,
    primary_login: primary_login,
    accounts: accounts,
    reason: failed_requests.empty? ? "missing_calendar" : failed_requests.first.fetch("reason")
  )
  write_payload(OUTPUT_PATH, payload)
  abort "GitHub contributions calendar is unavailable for #{logins.join(', ')}." if strict_mode?
  puts "GitHub contributions calendar is unavailable."
  exit 0
end

payload = enrich_payload_with_active_year(
  {
    "enabled" => true,
    "title" => title,
    "login" => primary_login,
    "accounts" => accounts,
    "account_graphs" => account_graphs,
    "fetched_at" => now.iso8601,
    "updated_label" => "마지막 동기화 #{now.strftime('%Y.%m.%d %H:%M')}",
    "available_years" => year_ranges.map { |year_range| year_range.fetch(:year) },
    "years" => [],
    "errors" => failed_requests
  }
)

write_payload(OUTPUT_PATH, payload)
puts "GitHub contributions cache updated for #{logins.join(', ')}."
