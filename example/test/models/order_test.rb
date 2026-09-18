require "test_helper"

class OrderTest < ActiveSupport::TestCase
  test "coerces messy status text onto the enum" do
    stub = stub_hunch(answer: :shipped)
    assert_equal :shipped, Order.import_status("sent it out tuesday??")

    question = stub.calls.first[:questions][:answer]
    assert_equal %i[pending shipped delivered cancelled], question.options.keys
  end
end
