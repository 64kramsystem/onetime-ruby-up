require_relative 'api'
require_relative 'version'
require_relative 'cli/parser'
require_relative 'cli/runner'

module Onetime
  module CLI
    def self.run(argv, stdin: $stdin, stdout: $stdout, stderr: $stderr)
      parsed = Parser.parse(argv)
      Runner.new(parsed, stdin: stdin, stdout: stdout, stderr: stderr).run
    rescue Parser::Error, Runner::Error, RuntimeError => e
      stderr.puts e.message
      1
    rescue StandardError => e
      stdout.puts e.message
      stdout.puts e.backtrace
      1
    end
  end
end
