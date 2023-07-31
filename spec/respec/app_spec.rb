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

  describe "#program_args" do
    it "should run through a binstub if present" do
      FileUtils.mkdir "#{tmp}/bin"
      FileUtils.touch "#{tmp}/bin/rspec"
      Dir.chdir tmp do
        app = Respec::App.new
        expect(app.program_args).to eq ['bin/rspec']
      end
    end

    it "should otherwise run through bundler if a Gemfile is present" do
      FileUtils.touch "#{tmp}/Gemfile"
      Dir.chdir tmp do
        app = Respec::App.new
        expect(app.program_args).to eq ['bundle', 'exec', 'rspec']
      end
    end

    it "should check the BUNDLE_GEMFILE environment variable if set" do
      with_hash_value ENV, 'BUNDLE_GEMFILE', "#{tmp}/custom_gemfile" do
        FileUtils.touch "#{tmp}/custom_gemfile"
        Dir.chdir tmp do
          app = Respec::App.new
          expect(app.program_args).to eq ['bundle', 'exec', 'rspec']
        end
      end
    end

    it "should not run through bundler if no Gemfile is present" do
      with_hash_value ENV, 'BUNDLE_GEMFILE', nil do
        Dir.chdir tmp do
          app = Respec::App.new
          expect(app.program_args).to eq ['rspec']
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
    def in_git_repo
      dir = "#{tmp}/repo"
      FileUtils.mkdir_p dir
      Dir.chdir(dir) do
        system 'git init --quiet .'
        yield
      end
    end

    def make_git_file(path, index_status, status)
      FileUtils.mkdir_p File.dirname(path)

      unless index_status == nil || index_status == :new
        open(path, 'w') { |f| f.print 1 }
        system "git add #{path.shellescape}"
        system "git commit --quiet --message . #{path.shellescape}"
      end

      case index_status
      when :new, :updated
        open(path, 'w') { |f| f.print 2 }
      when :up_to_date, nil
      when :removed
        File.delete path
      else
        raise ArgumentError, "invalid index_status: #{index_status}"
      end

      system "git add -- #{path.shellescape}" unless index_status.nil?

      case status
      when :new, :updated
        open(path, 'w') { |f| f.print 3 }
      when :up_to_date
      when :removed
        File.delete path
      else
        raise ArgumentError, "invalid status: #{status}"
      end
    end

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

    it "should run all new and updated files if 'd' is given" do
      in_git_repo do
        make_git_file 'a/01.rb', nil, :new

        make_git_file 'a/02.rb', :new, :up_to_date
        make_git_file 'a/03.rb', :new, :updated
        make_git_file 'a/04.rb', :new, :removed

        make_git_file 'a/05.rb', :up_to_date, :up_to_date
        make_git_file 'a/06.rb', :up_to_date, :updated
        make_git_file 'a/07.rb', :up_to_date, :removed

        make_git_file 'a/08.rb', :updated, :up_to_date
        make_git_file 'a/09.rb', :updated, :updated
        make_git_file 'a/10.rb', :updated, :removed

        make_git_file 'a/11.rb', :removed, :up_to_date
        make_git_file 'a/12.rb', :removed, :new

        app = Respec::App.new('d', 'a')
        expect(app.generated_args).to \
          contain_exactly(*[1, 2, 3, 6, 8, 9, 12].map { |i| 'a/%02d.rb' % i})
      end
    end

    it "should only include .rb files for 'd'" do
      in_git_repo do
        make_git_file 'a/1.rb', :new, :up_to_date
        make_git_file 'a/1.br', :new, :up_to_date

        app = Respec::App.new('d', 'a')
        expect(app.generated_args).to eq %w[a/1.rb]
      end
    end

    it "should not include files outside the given spec directories for 'd'" do
      in_git_repo do
        make_git_file 'a/1.rb', :new, :up_to_date
        make_git_file 'b/1.rb', :new, :up_to_date
        make_git_file 'c/1.rb', :new, :up_to_date

        app = Respec::App.new('d', 'a', 'b')
        expect(app.generated_args).to eq %w[a/1.rb b/1.rb]
      end
    end

    it "should filter files from the default spec directory for 'd'" do
      in_git_repo do
        make_git_file 'spec/1.rb', :new, :up_to_date
        make_git_file 'other/1.rb', :new, :up_to_date

        app = Respec::App.new('d')
        expect(app.generated_args).to eq %w[spec/1.rb]
      end
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

    it "should pass existing file names with discriminators in square brackets directly to rspec" do
      FileUtils.touch "#{tmp}/existing.rb"
      app = Respec::App.new("#{tmp}/existing.rb[1:22:333]")
      expect(app.generated_args).to eq ["#{tmp}/existing.rb[1:22:333]"]
    end

    it "should truncate line numbers when using numeric arguments" do
      make_failures_file 'a'
      FileUtils.touch "#{tmp}/existing.rb"
      app = Respec::App.new("#{tmp}/existing.rb:123", '1')
      expect(app.generated_args).to eq ['-e', 'a', "#{tmp}/existing.rb"]
    end

    it "should truncate square brackets when using numeric arguments" do
      make_failures_file 'a'
      FileUtils.touch "#{tmp}/existing.rb"
      app = Respec::App.new("#{tmp}/existing.rb[1:22:333]", '1')
      expect(app.generated_args).to eq ['-e', 'a', "#{tmp}/existing.rb"]
    end

    it "should truncate line numbers when rerunning all failures" do
      make_failures_file 'a'
      FileUtils.touch "#{tmp}/existing.rb"
      app = Respec::App.new("#{tmp}/existing.rb:123", 'f')
      expect(app.generated_args).to eq ['-e', 'a', "#{tmp}/existing.rb"]
    end

    it "should truncate square brackets when rerunning all failures" do
      make_failures_file 'a'
      FileUtils.touch "#{tmp}/existing.rb"
      app = Respec::App.new("#{tmp}/existing.rb[1:22:333]", 'f')
      expect(app.generated_args).to eq ['-e', 'a', "#{tmp}/existing.rb"]
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

  describe "#error" do
    it "should not be set if the arguments are valid" do
      make_failures_file 'a'
      app = Respec::App.new('1')
      expect(app.error).to be_nil
    end

    it "should be set if an invalid failure is given" do
      make_failures_file 'a', 'b'
      app = Respec::App.new('3')
      expect(app.error).to include 'invalid failure: 3 for (1..2)'
    end
  end
end
