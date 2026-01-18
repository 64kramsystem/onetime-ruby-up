require_relative "lib/onetime/version"

Gem::Specification.new do |s|
  s.name        = "onetime-up"
  s.version     = Onetime::VERSION
  s.authors     = [
    "Delano Mandelbaum",
    "Saverio Miroddi",
  ]
  s.email       = [
    "delano@onetimesecret.com",
    "saverio.pub2@gmail.com"
  ]
  s.homepage    = "https://github.com/onetimesecret/onetime-ruby-up"
  s.summary     = "Command-line tool and library for onetimesecret.com API (API v2)"
  s.description = "A Ruby library and command-line tool for sharing secrets securely using the onetimesecret.com API. Create and retrieve one-time secret links for sensitive information."
  s.licenses    = ["MIT"]

  s.required_ruby_version = ">= 3.2"
  s.required_rubygems_version = ">= 2.0.0"

  s.metadata = {
    "source_code_uri" => "https://github.com/onetimesecret/onetime-ruby-up",
  }

  s.files         = Dir["lib/**/*", "bin/*", "LICENSE.txt", "README.md", "CHANGELOG.md"].reject { |f| File.directory?(f) }
  s.executables   = Dir["bin/*"].map { |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "drydock", "~> 1.0.0"
  s.add_runtime_dependency "httparty", "~> 0.24.2"

  s.add_development_dependency "rspec", "~> 3.0"
  s.add_development_dependency "webmock", "~> 3.0"
end

