# Hunch

Probabilistic control flow for Ruby.

Ruby gives you `if`, `case`, and `<=>` for facts. Hunch gives you the same
three moves for judgment calls. Every question is a conditional probability —
_how likely is this, given that_ — and the API reads that way:

```ruby
if Hunch.almost_certain?("this order is fraudulent", given: order.attributes)
  order.hold!
end
```

The English is the configuration. No prompts, no parsing, no tuning DSL.
Answers come from [TypeSafe's Jev](https://typesafe.ai), a System One model:
a single fast parallel pass that returns typed, calibrated probabilities
instead of text — fast and cheap enough to sit inside a request cycle.

## Installation

```ruby
gem "hunch"
```

```ruby
Hunch.configure do |config|
  config.api_key = ENV["TYPESAFE_API_KEY"]
end
```

## The three primitives

**`chance`** answers _whether_, as a probability:

```ruby
Hunch.chance("written by a real human, not spam", given: bio)  # => 0.87
```

Named levels collapse it into predicates:

```ruby
Hunch.possible?("fraudulent", given: order)        # chance >= 0.25
Hunch.likely?("fraudulent", given: order)          # chance >= 0.5
Hunch.probable?("fraudulent", given: order)        # chance >= 0.75
Hunch.almost_certain?("fraudulent", given: order)  # chance >= 0.93

Hunch.configure { |c| c.levels[:paranoid] = 0.99 }
Hunch.paranoid?("fraudulent", given: order)        # chance >= 0.99
```

**`pick`** answers _which_:

```ruby
Hunch.pick(:ham, :spam, given: email)                                  # => :spam
Hunch.pick(urgent: "needs a reply today", routine: "can wait",
           given: ticket)                                              # => :routine
```

**`rate`** answers _how much_, on an ordered scale:

```ruby
mood = Hunch.rate(:calm, :frustrated, :livid, given: email)
mood.level      # => :frustrated
mood.position   # => 1.4
mood >= :livid  # => false
```

If shuffling the options wouldn't change their meaning, use `pick`; if they
form a ladder, use `rate`. Options are bare symbols or `symbol: "description"`,
mixed freely, plus an optional `question:` when the options alone don't carry
it. The keywords `given` and `question` are reserved.

## Batching

Several questions about one piece of state cost one API call:

```ruby
result = Hunch.decide(given: mail.raw_source) do |q|
  q.probable? :urgent, "does this convey urgency?"
  q.pick      :team, billing: "payments", technical: "bugs", sales: "pricing"
  q.rate      :mood, :calm, :frustrated, :livid
end

result.urgent             # => 0.92
result.urgent?            # => true, past :probable
result.team               # => :technical
result.team_probabilities # => { billing: 0.08, technical: 0.85, sales: 0.07 }
result.mood.level         # => :livid
```

## In a Rails app

Everything below is lifted from [`example/`](example), a Rails app in this
repo — its test suite covers each snippet, and all of them have been run
against the live model.

### Validations

A validation method is just an `if`:

```ruby
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
```

```ruby
signup = Signup.new(display_name: "BEST-CRYPTO-DEALS dot example",
                    bio: "BUY CHEAP GOLD CLICK HERE best prices!!!")
signup.valid?          # => false
signup.errors[:bio]    # => ["reads like spam"]
```

The `rescue nil` is a deliberate policy: if the API is unreachable at save
time, the record saves anyway. Fail closed instead where it matters more,
like a spam gate.

### Inbound email

ActionMailbox routing without the regex graveyard:

```ruby
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
end
```

### Error triage

Replace the hand-maintained ignore-list with one judgment:

```ruby
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
  end
end

# config/initializers/error_reporting.rb
Rails.application.config.after_initialize do
  Rails.error.subscribe(ErrorTriage.new)
end
```

### Job retries

Exception classes don't tell you whether a failure is transient. Ask:

```ruby
class WebhookDeliveryJob < ApplicationJob
  rescue_from Delivery::Error do |error|
    if Hunch.likely?("retrying this failed delivery will succeed",
                     given: { error: error.message, attempts: executions })
      retry_job wait: 30.seconds
    else
      Rails.logger.warn("giving up on webhook: #{error.message}")
    end
  end

  def perform(url, payload)
    Delivery.post(url, payload)
  end
end
```

A `503 upstream timeout` retries; a `404 endpoint not found` doesn't.

### Enum coercion

Messy import data, typed by construction — `pick` can only return one of
your enum's values:

```ruby
class Order < ApplicationRecord
  enum :status, { pending: 0, shipped: 1, delivered: 2, cancelled: 3 }

  def self.import_status(raw)
    Hunch.pick(*statuses.keys.map(&:to_sym), given: raw,
      question: "which order status does this text describe?")
  end
end

Order.import_status("sent it out tuesday??") # => :shipped
```

### Moderation

```ruby
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
```

## Testing

The stub backend is just another backend:

```ruby
Hunch.backend = Hunch::Backends::Stub.new(fraud: 0.95, team: :billing, mood: :calm)
```

Stub values are keyed by question key (`:answer` for the single-shot
methods) and follow the question type: a probability or boolean for chance
and its predicates, a symbol or probabilities hash for `pick`, a level
symbol or position for `rate`. Unstubbed questions raise unless you pass
`default:`. The stub records `calls` for assertions:

```ruby
test "spam is dropped without a ticket" do
  Hunch.backend = Hunch::Backends::Stub.new(answer: :spam)
  assert_no_difference -> { Ticket.count } do
    receive_inbound_email_from_mail(subject: "You have WON", body: "claim your prize")
  end
end
```

## Configuration

```ruby
Hunch.configure do |config|
  config.api_key = "..."          # default: ENV["TYPESAFE_API_KEY"]
  config.model = "jev-latest"
  config.url = "https://api.typesafe.ai/v1/systemone"
  config.timeout = 5
  config.open_timeout = 2
  config.max_retries = 2          # 429/5xx/timeouts, with backoff, honours Retry-After
  config.levels[:paranoid] = 0.99
end
```

### Via OpenRouter

Jev speaks the same wire format through
[OpenRouter's Decisions endpoint](https://openrouter.ai/typesafe), so an
OpenRouter key works today without the TypeSafe waitlist:

```ruby
Hunch.configure do |config|
  config.api_key = ENV["OPENROUTER_API_KEY"]
  config.url = "https://openrouter.ai/api/alpha/decisions"
  config.model = "typesafe/jev-1.13"
end
```

## Honesty about backends

The interface is uniform; the guarantees are not. Jev's probabilities are
calibrated, its answers are typed by construction, and it responds in
milliseconds. A future LLM backend can implement the same three primitives,
but its confidences are estimates, not calibrated probabilities, and it is
orders of magnitude slower and more expensive. Same interface, different
guarantees — choose accordingly.

## License

MIT
