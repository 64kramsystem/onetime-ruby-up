require 'spec_helper'
require 'onetime/cli/parser'

RSpec.describe Onetime::CLI::Parser do
  def parse(*argv)
    described_class.parse(argv)
  end

  describe 'command identification' do
    it 'defaults to the share command when none is given' do
      result = parse
      expect(result.command).to eq('share')
    end

    it 'recognizes the share command' do
      expect(parse('share').command).to eq('share')
    end

    it 'recognizes the status command' do
      expect(parse('status').command).to eq('status')
    end

    it 'recognizes the generate command' do
      expect(parse('generate').command).to eq('generate')
    end

    it 'recognizes the secret command and its get alias' do
      expect(parse('secret', 'abc').command).to eq('secret')
      expect(parse('get', 'abc').command).to eq('secret')
    end

    it 'recognizes the receipt command' do
      expect(parse('receipt', 'abc').command).to eq('receipt')
    end

    it 'raises on an unknown command' do
      expect { parse('nope') }.to raise_error(Onetime::CLI::Parser::Error, /unknown command/i)
    end
  end

  describe 'global options' do
    it 'accepts -V/--version as a request to print the version' do
      expect(parse('-V').show_version).to be true
      expect(parse('--version').show_version).to be true
    end

    it 'sets the output format from -j/--json' do
      expect(parse('-j', 'status').format).to eq('json')
      expect(parse('--json', 'status').format).to eq('json')
    end

    it 'sets the output format from -y/--yaml' do
      expect(parse('-y', 'status').format).to eq('yaml')
      expect(parse('--yaml', 'status').format).to eq('yaml')
    end

    it 'leaves the format as nil for -s/--string' do
      expect(parse('-s', 'status').format).to be_nil
    end

    it 'accepts -f/--format with a value' do
      expect(parse('-f', 'json', 'status').format).to eq('json')
      expect(parse('-f', 'yaml', 'status').format).to eq('yaml')
      expect(parse('-f', 'csv', 'status').format).to eq('csv')
    end

    it 'treats -f string as the default (nil) format' do
      expect(parse('-f', 'string', 'status').format).to be_nil
    end

    it 'rejects unsupported formats' do
      expect { parse('-f', 'xml', 'status') }.to raise_error(Onetime::CLI::Parser::Error, /unsupported format/i)
    end

    it 'reads customer id, api key and base uri' do
      result = parse('-c', 'me@example.com', '-k', 'thekey', '-H', 'http://example.com/api', 'status')
      expect(result.custid).to eq('me@example.com')
      expect(result.apikey).to eq('thekey')
      expect(result.base_uri).to eq('http://example.com/api')
    end

    it 'sets debug from -D/--debug' do
      expect(parse('-D', 'status').debug).to be true
    end

    it 'accepts -r/--recipient as a global option' do
      expect(parse('-r', 'a@x.com', 'share').recipients).to eq(['a@x.com'])
    end
  end

  describe 'positional arguments' do
    it 'collects positional args after the command' do
      expect(parse('secret', 'KEY1').argv).to eq(['KEY1'])
    end

    it 'returns no positional args when none are given' do
      expect(parse('status').argv).to eq([])
    end

    it 'consumes command-level option flags so they do not leak into argv' do
      expect(parse('secret', '-p', 'pass', 'KEY1').argv).to eq(['KEY1'])
      expect(parse('share', '-t', '3600').argv).to eq([])
      expect(parse('generate', '-p', 'pass').argv).to eq([])
    end
  end

  describe 'command-level options' do
    it 'parses -t/--ttl for share and generate' do
      expect(parse('share', '-t', '3600').ttl).to eq(3600)
      expect(parse('generate', '--ttl', '7200').ttl).to eq(7200)
    end

    it 'parses -p/--passphrase for secret, share and generate' do
      expect(parse('secret', '-p', 'pass', 'KEY').passphrase).to eq('pass')
      expect(parse('share', '--passphrase', 'shh').passphrase).to eq('shh')
      expect(parse('generate', '-p', 'gen').passphrase).to eq('gen')
    end

    it 'accepts -r/--recipient as a command-level option' do
      expect(parse('share', '-r', 'a@x.com').recipients).to eq(['a@x.com'])
    end

    it 'combines global and command-level recipients in order' do
      expect(parse('-r', 'a@x.com', 'share', '-r', 'b@x.com').recipients).to eq(['a@x.com', 'b@x.com'])
    end

    it 'splits comma-separated recipient values' do
      expect(parse('share', '-r', 'a@x.com,b@x.com').recipients).to eq(['a@x.com', 'b@x.com'])
    end

    it 'rejects command-level options on commands that do not declare them' do
      expect { parse('status', '-t', '3600') }.to raise_error(Onetime::CLI::Parser::Error)
      expect { parse('receipt', '-p', 'pass', 'KEY') }.to raise_error(Onetime::CLI::Parser::Error)
    end
  end

  describe 'format flag precedence (drydock compatibility)' do
    it 'lets -s win over both -j and -y regardless of order' do
      expect(parse('-y', '-j', '-s', 'status').format).to be_nil
      expect(parse('-s', '-j', '-y', 'status').format).to be_nil
    end

    it 'lets -j win over -y regardless of order' do
      expect(parse('-y', '-j', 'status').format).to eq('json')
      expect(parse('-j', '-y', 'status').format).to eq('json')
    end
  end
end
