Hunch.configure do |config|
  config.backend = Hunch::Backends::SystemOne.new(
    url: "https://openrouter.ai/api/alpha/decisions",
    api_key: ENV["OPENROUTER_API_KEY"],
    model: "typesafe/jev-1.13"
  )
end
