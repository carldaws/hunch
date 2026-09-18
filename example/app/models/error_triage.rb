class ErrorTriage
  def report(error, handled:, severity: nil, context: {}, source: nil)
    verdict = Hunch.rate(
      ignore: "known noise, expected in normal operation",
      notify: "worth a look during working hours",
      page:   "users are impacted right now",
      given: { class: error.class.name, message: error.message, handled:, source: }
    )

    case verdict.level
    when :page then Pagerduty.trigger(error)
    when :notify then SlackNotifier.post(error)
    end

    verdict.level
  end
end
