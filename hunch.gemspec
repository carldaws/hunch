require_relative "lib/hunch/version"

Gem::Specification.new do |spec|
  spec.name = "hunch"
  spec.version = Hunch::VERSION
  spec.authors = ["Carl Dawson"]
  spec.email = ["carldawson@hey.com"]

  spec.summary = "Probabilistic control flow for Ruby"
  spec.description = "likely?, pick, and score: three primitives that let Ruby branch on judgment calls, " \
                     "answered by TypeSafe's Jev System One model or any backend you plug in."
  spec.homepage = "https://github.com/carldaws/hunch"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE.txt"]
  spec.require_paths = ["lib"]
end
