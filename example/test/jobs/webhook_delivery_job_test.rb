require "test_helper"

class WebhookDeliveryJobTest < ActiveJob::TestCase
  test "retries when the failure looks transient" do
    stub_hunch(answer: 0.9)
    with_failing_delivery("503 upstream timeout") do
      assert_enqueued_with(job: WebhookDeliveryJob) do
        WebhookDeliveryJob.perform_now("https://example.com/hook", { id: 1 })
      end
    end
  end

  test "gives up when the failure looks permanent" do
    stub_hunch(answer: 0.1)
    with_failing_delivery("404 endpoint not found") do
      assert_no_enqueued_jobs do
        WebhookDeliveryJob.perform_now("https://example.com/hook", { id: 1 })
      end
    end
  end

  private

  def with_failing_delivery(message)
    original = Delivery.method(:post)
    Delivery.define_singleton_method(:post) { |_url, _payload| raise Delivery::Error, message }
    yield
  ensure
    Delivery.define_singleton_method(:post, original)
  end
end
