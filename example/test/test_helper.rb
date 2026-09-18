ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    fixtures :all

    setup { Hunch.reset_configuration! }

    def stub_hunch(**answers)
      Hunch::Backends::Stub.new(**answers).tap { |stub| Hunch.backend = stub }
    end
  end
end
