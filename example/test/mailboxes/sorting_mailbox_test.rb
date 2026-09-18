require "test_helper"

class SortingMailboxTest < ActionMailbox::TestCase
  test "billing email becomes a billing ticket" do
    stub_hunch(answer: :billing)
    receive_inbound_email_from_mail(
      to: "in@example.com", from: "customer@example.com",
      subject: "Invoice is wrong", body: "My payouts have been failing for 3 days."
    )

    ticket = Ticket.last
    assert_equal "billing", ticket.team
    assert_equal "Invoice is wrong", ticket.subject
  end

  test "spam is dropped without a ticket" do
    stub_hunch(answer: :spam)
    assert_no_difference -> { Ticket.count } do
      receive_inbound_email_from_mail(
        to: "in@example.com", from: "rich@example.com",
        subject: "You have WON", body: "claim your prize now"
      )
    end
  end
end
