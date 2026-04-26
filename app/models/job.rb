class Job < ApplicationRecord
  belongs_to :server, optional: true

  enum :status, { unprocessed: "unprocessed", pending: "pending", processed: "processed", error: "error" }, validate: true

  validates :prompt, length: { maximum: 80_000 }
end
