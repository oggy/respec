require File.expand_path('../spec_helper', File.dirname(__FILE__))
require 'fileutils'

describe Respec::App do
  use_temporary_directory TMP

  FORMATTER_PATH = File.expand_path("#{ROOT}/lib/respec/formatter.rb", File.dirname(__FILE__))
  FAIL_PATH = "#{TMP}/failures.txt"

  Respec::App.failures_path = FAIL_PATH

  def write_file(path, content)
    open(path, 'w') { |f| f.print content }
  end

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
      make_failures_file 'a.rb:1'
      app = Respec::App.new('f')
      expect(app.formatter_args).to eq [FORMATTER_PATH]
    end

    it "should not update the stored failures if a numeric argument is given" do
      make_failures_file 'a.rb:1'
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
      make_failures_file 'a.rb:1', 'b.rb:2'
      app = Respec::App.new('f')
      expect(app.generated_args).to eq ['a.rb:1', 'b.rb:2']
    end

    it "should run the n-th failure if a numeric argument 'n' is given" do
      make_failures_file 'a.rb:1', 'b.rb:2'
      app = Respec::App.new('2')
      expect(app.generated_args).to eq ['b.rb:2']
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
      FileUtils.touch "#{tmp}/FILE"
      app = Respec::App.new("#{tmp}/FILE")
      expect(app.generated_args).to eq ["#{tmp}/FILE"]
    end

    it "should not include named files if a numeric argument is given" do
      FileUtils.touch "#{tmp}/FILE"
      make_failures_file 'a.rb:1'
      app = Respec::App.new("#{tmp}/FILE", '1')
      expect(app.generated_args).to eq ['a.rb:1']
    end

    it "should not include named files if an 'f' argument is given" do
      FileUtils.touch "#{tmp}/FILE"
      make_failures_file 'a.rb:1'
      app = Respec::App.new("#{tmp}/FILE", 'f')
      expect(app.generated_args).to eq ['a.rb:1']
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

    it "should not add the spec directory if a numeric argument is given" do
      make_failures_file 'a.rb:1'
      app = Respec::App.new('1')
      expect(app.generated_args).to eq ["a.rb:1"]
    end

    it "should not add the spec directory if an 'f' argument is given" do
      make_failures_file 'a.rb:1'
      app = Respec::App.new('f')
      expect(app.generated_args).to eq ["a.rb:1"]
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
