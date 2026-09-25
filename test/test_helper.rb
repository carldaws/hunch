require "minitest/autorun"
require "hunch"

module StubHelpers
  def setup
    Hunch.reset_configuration!
  end

  def stub_backend(**answers)
    Hunch::Backends::Stub.new(answers).tap { |stub| Hunch.backend = stub }
  end
end
