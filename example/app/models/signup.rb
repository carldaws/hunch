class Signup < ApplicationRecord
  validates :email, presence: true
  validate :display_name_is_a_name, :bio_reads_like_a_human

  private

  def display_name_is_a_name
    return if display_name.blank?
    return if Hunch.likely?("a plausible human or company name, not an advert or URL", given: display_name)

    errors.add(:display_name, "doesn't look like a name")
  rescue Hunch::APIError
    nil
  end

  def bio_reads_like_a_human
    return if bio.blank?
    return if Hunch.probable?("a genuine human bio, not spam or keyword stuffing", given: bio)

    errors.add(:bio, "reads like spam")
  rescue Hunch::APIError
    nil
  end
end
