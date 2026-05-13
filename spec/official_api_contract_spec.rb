require 'json'
require 'open-uri'
require 'spec_helper'

RSpec.describe 'Official v2 API contract', :official_spec do
  let(:contract) do
    JSON.parse(URI.open('https://api.onetimesecret.com/doc/api-v2.json').read)
  end

  it 'keeps the client aligned with v2 conceal, generate, reveal, and receipt shapes' do
    paths = contract.fetch('paths')

    conceal = paths.fetch('/api/v2/secret/conceal').fetch('post')
    conceal_secret = conceal.dig('requestBody', 'content', 'application/json', 'schema', 'properties', 'secret')
    expect(conceal_secret.fetch('required')).to include('secret')
    expect(conceal.dig('responses', '200', 'content', 'application/json', 'schema', 'properties', 'record', 'properties').keys)
      .to include('receipt', 'secret')

    generate = paths.fetch('/api/v2/secret/generate').fetch('post')
    expect(generate.dig('requestBody', 'content', 'application/json', 'schema', 'required')).to include('secret')
    expect(generate.dig('responses', '200', 'content', 'application/json', 'schema', 'properties', 'record', 'properties').keys)
      .to include('receipt', 'secret')

    reveal = paths.fetch('/api/v2/secret/{identifier}/reveal').fetch('post')
    expect(reveal.dig('responses', '200', 'content', 'application/json', 'schema', 'properties', 'record', 'properties').keys)
      .to include('secret_value')

    receipt = paths.fetch('/api/v2/receipt/{identifier}').fetch('get')
    expect(receipt.dig('responses', '200', 'content', 'application/json', 'schema', 'properties', 'record', 'properties').keys)
      .to include('secret_identifier', 'recipients')
  end
end
