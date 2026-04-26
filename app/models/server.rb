class Server < ApplicationRecord
  has_many :jobs, dependent: :nullify

  validates :url, presence: true

  before_validation :normalize_url

  private

  def normalize_url
    return if url.blank?
    self.url = "https://#{url}" unless url.match?(%r{\Ahttps?://})
    self.url = url.chomp("/")
  end
end
