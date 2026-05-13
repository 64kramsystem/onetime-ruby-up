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

      COMMAND_OPTIONS = {
        'share'    => %i[ttl passphrase recipient].freeze,
        'generate' => %i[ttl passphrase recipient].freeze,
        'secret'   => %i[passphrase].freeze,
        'receipt'  => [].freeze,
        'status'   => [].freeze,
      }.freeze

      Result = Struct.new(
        :command, :argv,
        :base_uri, :custid, :apikey, :recipients,
        :format, :debug, :show_version,
        :ttl, :passphrase,
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
        @ttl = nil
        @passphrase = nil
        @yaml_flag = false
        @json_flag = false
        @string_flag = false
      end

      def parse
        global_option_parser.order!(@argv)
        command, rest = extract_command
        if command
          command_option_parser(command).order!(rest)
        end
        apply_format_precedence!
        normalize_format!
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
          ttl: @ttl,
          passphrase: @passphrase,
        )
      rescue OptionParser::ParseError => e
        raise Error, e.message
      end

      private

      def global_option_parser
        OptionParser.new do |opts|
          opts.on('-H BASE_URI', String) { |v| @base_uri = v }
          opts.on('-c CUSTID', '--custid CUSTID', String) { |v| @custid = v }
          opts.on('-k APIKEY', '--apikey APIKEY', String) { |v| @apikey = v }
          opts.on('-r RECIPIENT', '--recipient RECIPIENT', Array) { |v| @recipients.concat(Array(v)) }
          opts.on('-f FORMAT', '--format FORMAT', String) { |v| @format = v }
          opts.on('-j', '--json') { @json_flag = true }
          opts.on('-y', '--yaml') { @yaml_flag = true }
          opts.on('-s', '--string') { @string_flag = true }
          opts.on('-D', '--debug') { @debug = true }
          opts.on('-V', '--version') { @show_version = true }
        end
      end

      def command_option_parser(command)
        allowed = COMMAND_OPTIONS.fetch(command, [])
        OptionParser.new do |opts|
          if allowed.include?(:ttl)
            opts.on('-t TTL', '--ttl TTL', Integer) { |v| @ttl = v }
          end
          if allowed.include?(:passphrase)
            opts.on('-p PASSPHRASE', '--passphrase PASSPHRASE', String) { |v| @passphrase = v }
          end
          if allowed.include?(:recipient)
            opts.on('-r RECIPIENT', '--recipient RECIPIENT', Array) { |v| @recipients.concat(Array(v)) }
          end
        end
      end

      def apply_format_precedence!
        @format = 'yaml' if @yaml_flag
        @format = 'json' if @json_flag
        @format = 'string' if @string_flag
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
