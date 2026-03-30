# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "ruby-context"
  spec.version       = "0.1.0"
  spec.authors       = ["Kekzuke", "Zurak", "asthmatick1dd0"]
  spec.email         = ["asthmatick1dd0@gmail.com"]

  spec.summary       = "Go-like context library for Ruby"
  spec.description   = "A Ruby implementation of Go-like contexts for managing cancellation, deadlines, and values across goroutine-like abstractions"
  spec.homepage      = "https://github.com/asthmatick1dd0/ruby-context"
  spec.license       = "GPL-3.0"

  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.metadata = {
    "homepage_uri" => "https://github.com/asthmatick1dd0/ruby-context",
    "bug_tracker_uri" => "https://github.com/asthmatick1dd0/ruby-context/issues",
    "changelog_uri" => "https://github.com/asthmatick1dd0/ruby-context/releases"
  }
end
