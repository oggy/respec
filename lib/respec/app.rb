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
      @failures_path = self.class.default_failures_path
      @update_failures = true
      @error = nil
      process_args
    end

    attr_accessor :failures_path

    def error
      command
      @error
    end

    def command
      @command ||= program_args + generated_args + raw_args + formatter_args
    end

    def program_args
      if File.exist?('bin/rspec')
        ['bin/rspec']
      elsif File.exist?(ENV['BUNDLE_GEMFILE'] || 'Gemfile')
        ['bundle', 'exec', 'rspec']
      else
        ['rspec']
      end
    end

    attr_reader :generated_args, :raw_args

    def formatter_args
      if @update_failures
        [File.expand_path('formatter.rb', File.dirname(__FILE__))]
      else
        []
      end
    end

    class << self
      attr_accessor :default_failures_path
    end
    self.default_failures_path = ENV['RESPEC_FAILURES'] || File.expand_path(".respec_failures")

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
        |  d              Run all spec files changed since the last git commit
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
      using_filters = false
      changed_only = false
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
        elsif arg =~ /\AFAILURES=(.*)\z/
          self.failures_path = $1
        elsif arg == 'd'
          changed_only = true
        elsif arg == 'f'
          # failures_path could still be overridden -- delay evaluation of this.
          args << lambda do
            if File.exist?(failures_path)
              if failures.empty?
                STDERR.puts "No specs failed!"
                []
              else
                failures.flat_map { |f| ['-e', f] }
              end
            else
              warn "no fail file - ignoring 'f' argument"
              []
            end
          end
          using_filters = true
        elsif arg =~ /\A\d+\z/
          i = Integer(arg)
          if (failure = failures[i - 1])
            args << '-e' << failure
            @update_failures = false
            using_filters = true
          else
            @error = "invalid failure: #{i} for (1..#{failures.size})"
          end
        else
          args << '-e' << arg.gsub(/[$]/, '\\\\\\0')
        end
      end

      expanded = []
      args.each do |arg|
        if arg.respond_to?(:call)
          expanded.concat(arg.call)
        else
          expanded << arg
        end
      end

      # If rerunning failures, chop off explicit line numbers, as they are
      # additive, and filters are subtractive.
      if using_filters
        files.map! { |f| f.sub(/:\d+\z/, '') }
      end

      # Since we append our formatter as a file to run, rspec won't fall back to
      # using 'spec' by default. Add it explicitly here.
      files << 'spec' if files.empty?

      # Filter files only to those changed if 'd' is present.
      if changed_only
        files = changed_paths(files)
      end

      # If we selected individual failures to rerun, don't give the files to
      # rspec, as those files will be run in their entirety.
      @generated_args = expanded
      @generated_args.concat(files)
    end

    def changed_paths(paths)
      changes = `git status --short --untracked-files=all #{paths.shelljoin}`
      changes.lines.map do |line|
        path = line[3..-1].chomp
        path if File.exist?(path) && path =~ /\.rb\z/i
      end.compact.uniq
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
