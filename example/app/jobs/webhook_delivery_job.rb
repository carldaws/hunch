class WebhookDeliveryJob < ApplicationJob
  rescue_from Delivery::Error do |error|
    if Hunch.likely?("retrying this failed delivery will succeed",
                     given: { error: error.message, attempts: executions })
      retry_job wait: 30.seconds
    else
      Rails.logger.warn("giving up on webhook: #{error.message}")
    end
  end

  def perform(url, payload)
    Delivery.post(url, payload)
  end
end
