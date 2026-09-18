Rails.application.config.after_initialize do
  Rails.error.subscribe(ErrorTriage.new) unless Rails.env.test?
end
