class Order < ApplicationRecord
  enum :status, { pending: 0, shipped: 1, delivered: 2, cancelled: 3 }

  def self.import_status(raw)
    Hunch.pick(*statuses.keys.map(&:to_sym), given: raw,
      question: "which order status does this text describe?")
  end
end
