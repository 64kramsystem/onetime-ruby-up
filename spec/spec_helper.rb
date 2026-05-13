require 'bundler/setup'
require 'webmock/rspec'
require_relative '../lib/onetime/api'

module RateLimitHelpers
  def wait_for_rate_limit
    sleep 1 unless ENV['FAST']
  end
end

RSpec.configure do |config|
  config.include RateLimitHelpers

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.disable_monkey_patching!
  config.warnings = true

  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  config.filter_run_excluding integration: true unless ENV['ONETIME_INTEGRATION']
  config.filter_run_excluding official_spec: true unless ENV['ONETIME_VALIDATE_OFFICIAL_SPEC']

  # Disable WebMock for integration tests to allow real HTTP connections
  config.before(:each, :integration) do
    WebMock.allow_net_connect!
  end

  config.before(:each, :official_spec) do
    WebMock.allow_net_connect!
  end

  config.after(:each, :integration) do
    WebMock.disable_net_connect!
  end

  config.after(:each, :official_spec) do
    WebMock.disable_net_connect!
  end

  config.order = :random
  Kernel.srand config.seed
end
