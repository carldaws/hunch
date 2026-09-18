module Pagerduty
  def self.trigger(error)
    Rails.logger.error("[pagerduty] paging on-call: #{error.class}: #{error.message}")
  end
end
