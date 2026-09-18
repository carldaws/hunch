class Comment < ApplicationRecord
  enum :status, { pending: 0, published: 1, held: 2, rejected: 3 }, default: :pending

  def moderate!
    tone = Hunch.rate(:civil, :heated, :abusive, given: body,
      question: "how abusive is this comment?")

    case tone.level
    when :civil then published!
    when :heated then held!
    when :abusive then rejected!
    end
  end
end
