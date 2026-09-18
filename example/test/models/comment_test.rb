require "test_helper"

class CommentTest < ActiveSupport::TestCase
  test "publishes civil comments" do
    stub_hunch(answer: :civil)
    comment = Comment.create!(body: "great write-up, thanks for sharing")
    comment.moderate!
    assert comment.published?
  end

  test "holds heated comments for review" do
    stub_hunch(answer: :heated)
    comment = Comment.create!(body: "this take is embarrassingly wrong")
    comment.moderate!
    assert comment.held?
  end

  test "rejects abusive comments" do
    stub_hunch(answer: :abusive)
    comment = Comment.create!(body: "…")
    comment.moderate!
    assert comment.rejected?
  end
end
