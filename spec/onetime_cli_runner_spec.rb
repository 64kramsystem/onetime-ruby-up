require 'spec_helper'
require 'stringio'
require 'onetime/cli'

RSpec.describe Onetime::CLI::Runner do
  def parsed(**overrides)
    defaults = {
      command: nil,
      argv: [],
      base_uri: nil,
      custid: nil,
      apikey: nil,
      recipients: [],
      format: nil,
      debug: false,
      show_version: false,
      ttl: nil,
      passphrase: nil,
    }
    Onetime::CLI::Parser::Result.new(**defaults.merge(overrides))
  end

  def run(result, stdin_data: '')
    stdin = StringIO.new(stdin_data)
    stdout = StringIO.new
    stderr = StringIO.new
    exitcode =
      begin
        described_class.new(result, stdin: stdin, stdout: stdout, stderr: stderr).run
      rescue Onetime::CLI::Runner::Error, Onetime::CLI::Parser::Error, RuntimeError => e
        stderr.puts e.message
        1
      end
    { exitcode: exitcode, stdout: stdout.string, stderr: stderr.string }
  end

  describe 'pre-API logic (no network)' do
    it 'prints the version when show_version is set' do
      result = run(parsed(show_version: true))
      expect(result[:exitcode]).to eq(0)
      expect(result[:stdout]).to eq("#{Onetime::VERSION}\n")
    end

    it 'errors when receipt is invoked without a key' do
      result = run(parsed(command: 'receipt', argv: []))
      expect(result[:exitcode]).to eq(1)
      expect(result[:stderr]).to match(/Usage.*receipt/i)
    end

    it 'errors when secret is invoked without a key' do
      result = run(parsed(command: 'secret', argv: []))
      expect(result[:exitcode]).to eq(1)
      expect(result[:stderr]).to match(/Usage.*secret/i)
    end

    it 'rejects csv format for receipt' do
      result = run(parsed(command: 'receipt', argv: ['KEY'], format: 'csv'))
      expect(result[:exitcode]).to eq(1)
      expect(result[:stderr]).to match(/csv not supported/i)
    end

    it 'rejects csv format for secret' do
      result = run(parsed(command: 'secret', argv: ['KEY'], format: 'csv'))
      expect(result[:exitcode]).to eq(1)
      expect(result[:stderr]).to match(/csv not supported/i)
    end

    it 'rejects generate when stdin is piped' do
      result = run(parsed(command: 'generate'), stdin_data: "junk\n")
      expect(result[:exitcode]).to eq(1)
      expect(result[:stderr]).to match(/stdin/i)
    end

    it 'rejects share when both stdin and file produce no content' do
      result = run(parsed(command: 'share'), stdin_data: '')
      expect(result[:exitcode]).to eq(1)
      expect(result[:stderr]).to match(/No secret provided/i)
    end

    it 'exits cleanly when share input is interrupted' do
      stdin = double('stdin')
      allow(stdin).to receive(:tty?).and_return(true)
      allow(stdin).to receive(:read).and_raise(Interrupt)
      stdout = StringIO.new
      stderr = StringIO.new
      exitcode = described_class.new(
        parsed(command: 'share'),
        stdin: stdin, stdout: stdout, stderr: stderr
      ).run
      expect(exitcode).to eq(0)
      expect(stdout.string).to match(/Exiting/i)
    end
  end

  describe 'share input routing' do
    it 'reads stdin when a "-" positional arg is passed' do
      stdin = StringIO.new("piped-payload\n")
      stdout = StringIO.new
      stderr = StringIO.new
      runner = described_class.new(
        parsed(command: 'share', argv: ['-']),
        stdin: stdin, stdout: stdout, stderr: stderr
      )
      # Stub the API call so we can assert on the payload passed in
      api = double('api')
      response = double('response', code: 200)
      payload = nil
      allow(api).to receive(:post) do |_, opts|
        payload = opts[:secret]
        { 'record' => { 'secret' => { 'key' => 'abc' } } }
      end
      allow(api).to receive(:response).and_return(response)
      allow(OT::API).to receive(:new).and_return(api)
      allow(OT::API).to receive(:secret_key_from_response).and_return('abc')
      allow(OT::API).to receive(:web_uri).and_return('https://example.com/secret/abc')
      allow(OT::API).to receive(:recipients_from_response).and_return([])

      exitcode = runner.run
      expect(exitcode).to eq(0)
      expect(payload).to eq("piped-payload\n")
    end
  end
end
