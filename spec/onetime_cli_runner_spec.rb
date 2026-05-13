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
  end
end
