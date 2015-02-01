require File.expand_path('../spec_helper', File.dirname(__FILE__))
require 'fileutils'

describe Respec::App do
  use_temporary_directory TMP

  FORMATTER_PATH = File.expand_path("#{ROOT}/lib/respec/formatter.rb", File.dirname(__FILE__))
  FAIL_PATH = "#{TMP}/failures.txt"

  Respec::App.default_failures_path = FAIL_PATH

  def make_failures_file(*examples)
    options = examples.last.is_a?(Hash) ? examples.pop : {}
    path = options[:path] || Respec::App.default_failures_path
    open path, 'w' do |file|
      examples.each do |example|
        file.puts example
      end
    end
  end

  describe "#failures_path" do
    it "defaults to the global default" do
      app = Respec::App.new
      expect(app.failures_path).to eq FAIL_PATH
    end

    it "can be overridden with a FAILURES= argument" do
      app = Respec::App.new('FAILURES=overridden.txt')
      expect(app.failures_path).to eq 'overridden.txt'
    end
  end

  describe "#bundler_args" do
    it "should run through bundler if a Gemfile is present" do
      FileUtils.touch "#{tmp}/Gemfile"
      Dir.chdir tmp do
        app = Respec::App.new
        expect(app.bundler_args).to eq ['bundle', 'exec']
      end
    end

    it "should check the BUNDLE_GEMFILE environment variable if set" do
      with_hash_value ENV, 'BUNDLE_GEMFILE', "#{tmp}/custom_gemfile" do
        FileUtils.touch "#{tmp}/custom_gemfile"
        Dir.chdir tmp do
          app = Respec::App.new
          expect(app.bundler_args).to eq ['bundle', 'exec']
        end
      end
    end

    it "should not run through bundler if no Gemfile is present" do
      with_hash_value ENV, 'BUNDLE_GEMFILE', nil do
        Dir.chdir tmp do
          app = Respec::App.new
          expect(app.bundler_args).to eq []
        end
      end
    end
  end

  describe "#formatter_args" do
    it "should update the stored failures if no args are given" do
      app = Respec::App.new
      expect(app.formatter_args).to eq [FORMATTER_PATH]
    end

    it "should update the stored failures if 'f' is used" do
      make_failures_file 'a'
      app = Respec::App.new('f')
      expect(app.formatter_args).to eq [FORMATTER_PATH]
    end

    it "should not update the stored failures if a numeric argument is given" do
      make_failures_file 'a'
      app = Respec::App.new('1')
      expect(app.formatter_args).to eq []
    end
  end

  describe "#generated_args" do
    it "should pass all arguments that start with '-' to rspec" do
      FileUtils.touch "#{tmp}/file"
      app = Respec::App.new('-a', '-b', '-c', "#{tmp}/file")
      expect(app.generated_args).to eq ['-a', '-b', '-c', "#{tmp}/file"]
    end

    it "should pass arguments for rspec options that need them" do
      FileUtils.touch "#{tmp}/file"
      expect(Respec::App.new('-I', 'lib', '-t', 'mytag', "#{tmp}/file").generated_args).to eq ['-I', 'lib', '-t', 'mytag', "#{tmp}/file"]
    end

    it "should run all failures if 'f' is given" do
      make_failures_file 'a', 'b'
      app = Respec::App.new('f')
      expect(app.generated_args).to eq ['-e', 'a', '-e', 'b', 'spec']
    end

    it "should pass failures with spaces in them as a single argument" do
      make_failures_file 'a a'
      app = Respec::App.new('f')
      expect(app.generated_args).to eq ['-e', 'a a', 'spec']
    end

    it "should find the right failures if the failures file is overridden after the 'f'" do
      make_failures_file 'a', 'b', path: "#{FAIL_PATH}-overridden"
      app = Respec::App.new('f', "FAILURES=#{FAIL_PATH}-overridden")
      expect(app.generated_args).to eq ['-e', 'a', '-e', 'b', 'spec']
    end

    it "should run the n-th failure if a numeric argument 'n' is given" do
      make_failures_file 'a', 'b'
      app = Respec::App.new('2')
      expect(app.generated_args).to eq ['-e', 'b', 'spec']
    end

    it "should interpret existing file names as file name arguments" do
      FileUtils.touch "#{tmp}/existing.rb"
      app = Respec::App.new("#{tmp}/existing.rb")
      expect(app.generated_args).to eq ["#{tmp}/existing.rb"]
    end

    it "should pass existing file names with line numbers directly to rspec" do
      FileUtils.touch "#{tmp}/existing.rb"
      app = Respec::App.new("#{tmp}/existing.rb:123")
      expect(app.generated_args).to eq ["#{tmp}/existing.rb:123"]
    end

    it "should treat other arguments as example names" do
      app = Respec::App.new('a', 'b')
      expect(app.generated_args).to eq ['-e', 'a', '-e', 'b', 'spec']
    end

    it "should include named files when a numeric argument is given" do
      FileUtils.touch "#{tmp}/FILE"
      make_failures_file 'a'
      app = Respec::App.new("#{tmp}/FILE", '1')
      expect(app.generated_args).to eq ['-e', 'a', "#{tmp}/FILE"]
    end

    it "should include named files when an 'f' argument is given" do
      FileUtils.touch "#{tmp}/FILE"
      make_failures_file 'a'
      app = Respec::App.new("#{tmp}/FILE", 'f')
      expect(app.generated_args).to eq ['-e', 'a', "#{tmp}/FILE"]
    end

    it "should explicitly add the spec directory if no files are given or errors to rerun" do
      app = Respec::App.new
      expect(app.generated_args).to eq ['spec']
    end

    it "should not add the spec directory if any files are given" do
      FileUtils.touch "#{tmp}/FILE"
      app = Respec::App.new("#{tmp}/FILE")
      expect(app.generated_args).to eq ["#{tmp}/FILE"]
    end

    it "should add the spec directory if a numeric argument is given without explicit files" do
      make_failures_file 'a'
      app = Respec::App.new('1')
      expect(app.generated_args).to eq ['-e', 'a', 'spec']
    end

    it "should add the spec directory when an 'f' argument is given without explicit files" do
      make_failures_file 'a'
      app = Respec::App.new('f')
      expect(app.generated_args).to eq ['-e', 'a', 'spec']
    end
  end

  describe "#raw_args" do
    it "should pass arguments after '--' directly to rspec" do
      app = Respec::App.new('--', '--blah')
      expect(app.raw_args).to eq ['--blah']
    end
  end

  describe "#command" do
    it "should combine all the args" do
      Dir.chdir tmp do
        FileUtils.touch 'Gemfile'
        app = Respec::App.new('--', '-t', 'TAG')
        expect(app.command).to eq ['bundle', 'exec', 'rspec', 'spec', '-t', 'TAG', FORMATTER_PATH]
      end
    end
  end
end
