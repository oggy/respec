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
      @formatter = 'progress'
      @selected_failures = false
      @update_failures = true
      process_args
    end

    def command
      @command ||= bundler_args + ['rspec'] + formatter_args + generated_args + raw_args
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
        ['--require', formatter_path, '--format', 'Respec::Formatter', '--out', failures_path, '--format', @formatter]
      else
        []
      end
    end

    attr_reader :generated_args, :raw_args

    class << self
      attr_accessor :failures_path
    end
    self.failures_path = ENV['RESPEC_FAILURES'] || File.expand_path("~/.respec_failures")

    def help_only?
      @help_only
    end

    def help
      <<-EOS.gsub(/^ *\|/, '')
        |USAGE: respec RESPEC-ARGS ... [ -- RSPEC-ARGS ... ]
        |
        |Run rspec recording failed examples for easy rerunning later.
        |
        |RESPEC-ARGS may consist of:
        |
        |  f            Rerun all failed examples
        |  <integer>    Rerun only the n-th failure
        |  <file name>  Run specs in these files
        |  <other>      Run only examples matching this pattern
        |  --help       This!  (Also 'help'.)
        |  -<anything>  Passed directly to rspec.
        |
        |RSPEC-ARGS may follow a '--' argument, and are also passed
        |directly to rspec.
        |
        |More info: http://github.com/oggy/respec
      EOS
    end

    private

    def process_args
      args = []
      files = []
      @args.each do |arg|
        if File.exist?(arg.sub(/:\d+\z/, ''))
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
        elsif arg == 's'
          @formatter = 'specdoc'
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
      # If we selected individual failures to rerun, don't give the
      # files to rspec, as those files will be run in entirety.
      @generated_args = args
      @generated_args.concat(files) unless @selected_failures
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
  end
end
