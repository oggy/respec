require 'set'

module Respec
  class App
    def initialize(*args)
      if (i = args.index('--'))
        @args = args.slice!(0...i)
        @raw_args = args[1..-1]
      else
        @args = args
        @raw_args = []
      end
      @selected_failures = false
      @update_failures = true
      process_args
    end

    def command
      @command ||= bundler_args + ['rspec'] + formatter_args + default_formatter_args + generated_args + raw_args
    end

    def bundler_args
      if File.exist?(ENV['BUNDLE_GEMFILE'] || 'Gemfile')
        ['bundle', 'exec']
      else
        []
      end
    end

    def formatter_args
      if @update_failures
        formatter_path = File.expand_path('formatter.rb', File.dirname(__FILE__))
        ['--require', formatter_path, '--format', 'Respec::Formatter', '--out', failures_path]
      else
        []
      end
    end

    def default_formatter_args
      args = @generated_args + @raw_args + dotfile_args
      if args.include?('-f') || args.include?('--format') || args.include?('--formatter')
        []
      else
        ['--format', 'progress']
      end
    end

    attr_reader :generated_args, :raw_args

    class << self
      attr_accessor :failures_path
      attr_accessor :local_rspec_config_path
      attr_accessor :global_rspec_config_path
    end
    self.failures_path = ENV['RESPEC_FAILURES'] || File.expand_path(".respec_failures")
    self.local_rspec_config_path = '.rspec'
    self.global_rspec_config_path = File.expand_path('~/.rspec')

    def help_only?
      @help_only
    end

    def help
      <<-EOS.gsub(/^ *\|/, '')
        |USAGE: respec RESPEC-ARGS ... [ -- RSPEC-ARGS ... ]
        |
        |Run rspec, recording failed examples for easy rerunning later.
        |
        |RESPEC-ARGS may consist of:
        |
        |  f              Rerun all failed examples
        |  <N>            Rerun only the N-th failure
        |  <file name>    Run all specs in this file
        |  <file name:N>  Run specs at line N in this file
        |  <other>        Run only examples matching this pattern
        |  -<anything>    Passed directly to rspec.
        |  --help         This!  (Also 'help'.)
        |
        |Any arguments following a '--' argument are passed directly to rspec.
        |
        |More info: http://github.com/oggy/respec
      EOS
    end

    private

    def process_args
      args = []
      files = []
      pass_next_arg = false
      @args.each do |arg|
        if pass_next_arg
          args << arg
          pass_next_arg = false
        elsif rspec_option_that_requires_an_argument?(arg)
          args << arg
          pass_next_arg = true
        elsif File.exist?(arg.sub(/:\d+\z/, ''))
          files << arg
        elsif arg =~ /\A(--)?help\z/
          @help_only = true
        elsif arg =~ /\A-/
          args << arg
        elsif arg == 'f'
          if File.exist?(failures_path)
            if failures.empty?
              abort "No specs failed!"
            else
              failures.each do |line|
                args << line.strip
              end
              @selected_failures = true
            end
          else
            warn "no fail file - ignoring 'f' argument"
          end
        elsif arg =~ /\A\d+\z/
          i = Integer(arg)
          if (failure = failures[i - 1])
            args << failure
            @selected_failures = true
            @update_failures = false
          else
            warn "invalid failure: #{i} for (1..#{failures.size})"
          end
        else
          args << '--example' << arg.gsub(/[$]/, '\\\\\\0')
        end
      end
      # If we selected individual failures to rerun, don't give the files to
      # rspec, as those files will be run in their entirety.
      @generated_args = args
      @generated_args.concat(files) unless @selected_failures
    end

    def dotfile_args
      [self.class.local_rspec_config_path, self.class.global_rspec_config_path].map do |path|
        File.exist?(path) ? File.read(path) : ''
      end.join(' ').split
    end

    def failures_path
      self.class.failures_path
    end

    def failures
      @failures ||=
        if File.exist?(failures_path)
          File.read(failures_path).split(/\n/)
        else
          []
        end
    end

    def rspec_option_that_requires_an_argument?(arg)
      RSPEC_OPTIONS_THAT_REQUIRE_AN_ARGUMENT.include?(arg)
    end

    RSPEC_OPTIONS_THAT_REQUIRE_AN_ARGUMENT = %w[
      -I
      -r --require
      -O --options
      --order
      --seed
      --failure-exit-code
      --drb-port
      -f --format --formatter
      -o --out
      -P --pattern
      -e --example
      -l --line_number
      -t --tag
      --default_path
    ].to_set
  end
end
