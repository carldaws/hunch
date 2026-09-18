class SortingMailbox < ApplicationMailbox
  def process
    team = Hunch.pick(
      support: "questions about using or configuring the product",
      billing: "invoices, payments, refunds",
      spam:    "unsolicited bulk or scam email",
      given: "Subject: #{mail.subject}\n\n#{body}"
    )
    return if team == :spam

    Ticket.create!(team: team.to_s, subject: mail.subject, body: body)
  end

  private

  def body
    (mail.text_part || mail).decoded
  end
end
