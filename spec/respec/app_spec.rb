require File.expand_path('../spec_helper', File.dirname(__FILE__))
require 'fileutils'

describe Respec::App do
  use_temporary_directory TMP

  FORMATTER_PATH = File.expand_path("#{ROOT}/lib/respec/formatter.rb", File.dirname(__FILE__))
  FAIL_PATH = "#{TMP}/failures.txt"

  Respec::App.failures_path = FAIL_PATH

  def make_failures_file(*examples)
    open Respec::App.failures_path, 'w' do |file|
      examples.each do |example|
        file.puts example
      end
    end
  end

  describe "#bundler_args" do
    it "should run through bundler if a Gemfile is present" do
      FileUtils.touch "#{tmp}/Gemfile"
      Dir.chdir tmp do
        app = Respec::App.new
        app.bundler_args.should == ['bundle', 'exec']
      end
    end

    it "should check the BUNDLE_GEMFILE environment variable if set" do
      with_hash_value ENV, 'BUNDLE_GEMFILE', "#{tmp}/custom_gemfile" do
        FileUtils.touch "#{tmp}/custom_gemfile"
        Dir.chdir tmp do
          app = Respec::App.new
          app.bundler_args.should == ['bundle', 'exec']
        end
      end
    end

    it "should not run through bundler if no Gemfile is present" do
      with_hash_value ENV, 'BUNDLE_GEMFILE', nil do
        Dir.chdir tmp do
          app = Respec::App.new
          app.bundler_args.should == []
        end
      end
    end
  end

  describe "#formatter_args" do
    it "should include the respec and progress formatters by default" do
      app = Respec::App.new
      app.formatter_args.should == ['--require', FORMATTER_PATH, '--format', 'Respec::Formatter', '--out', FAIL_PATH, '--format', 'progress']
    end

    it "should include '--format specdoc' if an 's' argument is given" do
      app = Respec::App.new('s')
      app.formatter_args.should == ['--require', FORMATTER_PATH, '--format', 'Respec::Formatter', '--out', FAIL_PATH, '--format', 'specdoc']
    end

    it "should update the stored failures if no args are given" do
      app = Respec::App.new
      app.formatter_args.should == ['--require', FORMATTER_PATH, '--format', 'Respec::Formatter', '--out', FAIL_PATH, '--format', 'progress']
    end

    it "should update the stored failures if 'f' is used" do
      make_failures_file 'a.rb:1'
      app = Respec::App.new('f')
      app.formatter_args.should == ['--require', FORMATTER_PATH, '--format', 'Respec::Formatter', '--out', FAIL_PATH, '--format', 'progress']
    end

    it "should not update the stored failures if a numeric argument is given" do
      make_failures_file 'a.rb:1'
      app = Respec::App.new('1')
      app.formatter_args.should == []
    end
  end

  describe "#generated_args" do
    it "should run with --context if 'c' is given" do
      app = Respec::App.new('c')
      app.generated_args.should == ['--diff', 'context']
    end

    it "should run all failures if 'f' is given" do
      make_failures_file 'a.rb:1', 'b.rb:2'
      app = Respec::App.new('f')
      app.generated_args.should == ['a.rb:1', 'b.rb:2']
    end

    it "should run via the debugger if 'd' is given" do
      app = Respec::App.new('d')
      app.generated_args.should == ['--debugger']
    end

    it "should run via DRb if 'X' is given" do
      app = Respec::App.new('X')
      app.generated_args.should == ['--drb']
    end

    it "should run via DRb if 'x' is given" do
      app = Respec::App.new('x')
      app.generated_args.should == ['--drb']
    end

    it "should run the n-th failure if a numeric argument 'n' is given" do
      make_failures_file 'a.rb:1', 'b.rb:2'
      app = Respec::App.new('2')
      app.generated_args.should == ['b.rb:2']
    end

    it "should interpret existing file names as file name arguments" do
      FileUtils.touch "#{tmp}/existing.rb"
      app = Respec::App.new("#{tmp}/existing.rb")
      app.generated_args.should == ["#{tmp}/existing.rb"]
    end

    it "should treat other arguments as example names" do
      FileUtils.touch "#{tmp}/FILE"
      app = Respec::App.new("#{tmp}/FILE")
      app.generated_args.should == ["#{tmp}/FILE"]
    end

    it "should not include named files if a numeric argument is given" do
      FileUtils.touch "#{tmp}/FILE"
      make_failures_file 'a.rb:1'
      app = Respec::App.new("#{tmp}/FILE", '1')
      app.generated_args.should == ['a.rb:1']
    end

    it "should not include named files if an 'f' argument is given" do
      FileUtils.touch "#{tmp}/FILE"
      make_failures_file 'a.rb:1'
      app = Respec::App.new("#{tmp}/FILE", 'f')
      app.generated_args.should == ['a.rb:1']
    end
  end

  describe "#raw_args" do
    it "should pass arguments after '--' directly to rspec" do
      app = Respec::App.new('--', '--blah')
      app.raw_args.should == ['--blah']
    end
  end

  describe "#command" do
    it "should combine all the args" do
      Dir.chdir tmp do
        FileUtils.touch 'Gemfile'
        app = Respec::App.new('c', '--', '-t', 'TAG')
        app.command.should == ['bundle', 'exec', 'rspec', '--require', FORMATTER_PATH, '--format', 'Respec::Formatter', '--out', FAIL_PATH, '--format', 'progress', '--diff', 'context', '-t', 'TAG']
      end
    end
  end
end
