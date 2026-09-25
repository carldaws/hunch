# Hunch

Probabilistic control flow for Ruby.

Hunch lets you ask questions about text or application data and use the
answers in your Ruby code.

```ruby
if Hunch.almost_certainly?("this order is fraudulent", given: order.attributes)
  order.hold!
end
```

You can get a probability, choose between options, or rate something on a
scale. Questions are written in plain English; answers come back as Ruby values.

Hunch asks a System One model, such as [TypeSafe's Jev](https://typesafe.ai),
which answers with calibrated probabilities rather than text.

## Installation

```ruby
gem "hunch"
```

Point Hunch at a System One endpoint. Jev is available through
[OpenRouter](https://openrouter.ai/typesafe):

```ruby
# config/initializers/hunch.rb
Hunch.configure do |config|
  config.backend = Hunch::Backends::SystemOne.new(
    url: "https://openrouter.ai/api/alpha/decisions",
    api_key: ENV["OPENROUTER_API_KEY"],
    model: "typesafe/jev-1.13"
  )
end
```

## Usage

**`chance`** returns a probability between 0 and 1:

```ruby
Hunch.chance("written by a real human, not spam", given: bio)  # => 0.87
```

Use a named threshold when you want a boolean:

```ruby
Hunch.possibly?("fraudulent", given: order)         # chance >= 0.25
Hunch.likely?("fraudulent", given: order)           # chance >= 0.5
Hunch.probably?("fraudulent", given: order)         # chance >= 0.75
Hunch.almost_certainly?("fraudulent", given: order) # chance >= 0.93

Hunch.configure { |c| c.levels[:definitely] = 0.99 }
Hunch.definitely?("fraudulent", given: order)        # chance >= 0.99
```

Configure built-in thresholds with the matching level names, for example
`Hunch.configure { |c| c.levels[:probably] = 0.8 }`.

**`pick`** chooses one of the options you provide:

```ruby
Hunch.pick(:ham, :spam, given: email)                                  # => :spam
Hunch.pick(urgent: "needs a reply today", routine: "can wait",
           given: ticket)                                              # => :routine
```

**`rate`** returns a rating with a position on an ordered scale:

```ruby
mood = Hunch.rate(:calm, :frustrated, :livid, given: email)
mood.level      # => :frustrated
mood.position   # => 1.4
mood >= :livid  # => false
```

Use `pick` for categories such as billing, support, and sales. Use `rate`
for ordered levels such as low, medium, and high.

Both accept symbols or `symbol: "description"` pairs, or a mix of the two.
Add `question:` if the options need more context. `given:` supplies the data
to evaluate. These two keywords are reserved and can't be used as option names.

## Batching

Use `Hunch.decide` to ask several questions about the same data in one API call:

```ruby
result = Hunch.decide(given: mail.raw_source) do |q|
  q.probably? :urgent, "does this convey urgency?"
  q.pick      :team, billing: "payments", technical: "bugs", sales: "pricing"
  q.rate      :mood, :calm, :frustrated, :livid
end

result.urgent             # => 0.92
result.urgent?            # => true, at or above :probably
result.team               # => :technical
result.team_probabilities # => { billing: 0.08, technical: 0.85, sales: 0.07 }
result.mood.level         # => :livid
```

## In a Rails app

The [`example/`](example) Rails app contains these examples and their tests.

### Validations

Check a display name and bio during validation:

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
    return if Hunch.probably?("a genuine human bio, not spam or keyword stuffing", given: bio)

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

These validations rescue `Hunch::APIError`, so an API failure adds no
validation error. Other validations, including the email presence check,
still apply.

### Inbound email

Route incoming email by its contents:

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

Choose whether to ignore an error, send a notification, or page someone:

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

Use the error message and attempt count to decide whether to retry:

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

### Enum coercion

Map imported text to an existing enum value:

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

Use the stub backend to supply answers without making API calls:

```ruby
Hunch.backend = Hunch::Backends::Stub.new({ fraud: 0.95, team: :billing, mood: :calm })
```

Use the question's key to supply its answer, or `:answer` for calls outside
a `Hunch.decide` block. Stub values depend on the method:

- `chance` and its predicates: a probability or boolean.
- `pick`: a symbol or a hash of probabilities.
- `rate`: a level symbol or numeric position.

Missing answers raise unless you pass a fallback, as in
`Hunch::Backends::Stub.new({}, fallback: 0.5)`. The stub records each call
in `calls` for assertions.

```ruby
test "spam is dropped without a ticket" do
  Hunch.backend = Hunch::Backends::Stub.new({ answer: :spam })
  assert_no_difference -> { Ticket.count } do
    receive_inbound_email_from_mail(subject: "You have WON", body: "claim your prize")
  end
end
```

## Configuration

```ruby
Hunch.configure do |config|
  config.backend = Hunch::Backends::SystemOne.new(
    url: "https://openrouter.ai/api/alpha/decisions",
    api_key: ENV["OPENROUTER_API_KEY"], # a missing key raises when you ask
    model: "typesafe/jev-1.13",
    timeout: 5,                         # seconds to read the response
    open_timeout: 2,                    # seconds to connect
    max_retries: 2                      # 429/5xx/timeouts, with backoff, honours Retry-After
  )
  config.levels[:definitely] = 0.99
end
```

## Errors

`Hunch::APIError` covers failures worth working around: timeouts, lost
connections, rate limits, server errors, and answers the backend got wrong
(`Hunch::InvalidAnswerError`). `AuthenticationError`, `ValidationError`, and
`ConfigurationError` mean your setup needs fixing, so they are not
`APIError`s.

## Backends

`Hunch::Backends::SystemOne` talks to any endpoint that speaks the System One
decisions protocol of noul, choice, and score questions. `Hunch::Backends::Stub`
is for [testing](#testing). A backend is any object with a
`decide(state:, questions:)` method that returns `{ "answers" => ... }`.

## License

MIT
