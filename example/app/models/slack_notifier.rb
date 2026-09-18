module SlackNotifier
  def self.post(error)
    Rails.logger.warn("[slack] for the morning: #{error.class}: #{error.message}")
  end
end
