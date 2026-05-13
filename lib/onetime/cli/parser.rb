require 'optparse'

require_relative '../version'

module Onetime
  module CLI
    class Parser
      class Error < StandardError; end

      DEFAULT_COMMAND = 'share'.freeze
      KNOWN_COMMANDS = %w[status receipt secret share generate].freeze
      COMMAND_ALIASES = { 'get' => 'secret' }.freeze
      VALID_FORMATS = %w[json yaml csv].freeze

      Result = Struct.new(
        :command, :argv,
        :base_uri, :custid, :apikey, :recipients,
        :format, :debug, :show_version,
        keyword_init: true,
      )

      def self.parse(argv)
        new(argv).parse
      end

      def initialize(argv)
        @argv = argv.dup
        @base_uri = nil
        @custid = nil
        @apikey = nil
        @recipients = []
        @format = nil
        @debug = false
        @show_version = false
      end

      def parse
        option_parser.order!(@argv)
        normalize_format!
        command, rest = extract_command
        Result.new(
          command: command,
          argv: rest,
          base_uri: @base_uri,
          custid: @custid,
          apikey: @apikey,
          recipients: @recipients,
          format: @format,
          debug: @debug,
          show_version: @show_version,
        )
      rescue OptionParser::ParseError => e
        raise Error, e.message
      end

      private

      def option_parser
        OptionParser.new do |opts|
          opts.on('-H BASE_URI', String) { |v| @base_uri = v }
          opts.on('-c CUSTID', '--custid CUSTID', String) { |v| @custid = v }
          opts.on('-k APIKEY', '--apikey APIKEY', String) { |v| @apikey = v }
          opts.on('-r RECIPIENT', '--recipient RECIPIENT', Array) { |v| @recipients.concat(Array(v)) }
          opts.on('-f FORMAT', '--format FORMAT', String) { |v| @format = v }
          opts.on('-j', '--json') { @format = 'json' }
          opts.on('-y', '--yaml') { @format = 'yaml' }
          opts.on('-s', '--string') { @format = 'string' }
          opts.on('-D', '--debug') { @debug = true }
          opts.on('-V', '--version') { @show_version = true }
        end
      end

      def normalize_format!
        @format = nil if @format == 'string'
        return if @format.nil?
        return if VALID_FORMATS.include?(@format)
        raise Error, "Unsupported format: #{@format}"
      end

      def extract_command
        return [nil, []] if @show_version

        raw = @argv.shift || DEFAULT_COMMAND
        canonical = COMMAND_ALIASES.fetch(raw, raw)
        unless KNOWN_COMMANDS.include?(canonical)
          raise Error, "unknown command: #{raw}"
        end
        [canonical, @argv]
      end
    end
  end
end
