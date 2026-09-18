Hunch.configure do |config|
  if ENV["OPENROUTER_API_KEY"]
    config.api_key = ENV["OPENROUTER_API_KEY"]
    config.url = "https://openrouter.ai/api/alpha/decisions"
    config.model = "typesafe/jev-1.13"
  end
end
