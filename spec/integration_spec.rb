require File.expand_path('spec_helper', File.dirname(__FILE__))
require 'rbconfig'

describe Respec do
  use_temporary_directory TMP

  CONFIG = (Object.const_defined?(:RbConfig) ? RbConfig : Config)::CONFIG
  def respec(args)
    # Rubinius can trip here as the simulated edits to the .rb files happen quickly enough that the
    # .rbc will look current. Blow away the .rbx directory to ensure the source is read each time.
    FileUtils.rm_rf '.rbx'

    ruby = File.join(CONFIG['bindir'], CONFIG['ruby_install_name'])
    respec = "#{ROOT}/bin/respec"
    output = `RESPEC_FAILURES=#{TMP}/failures.txt #{ruby} -I #{ROOT}/lib #{respec} #{args} 2>&1`
    [$?, output]
  end

  def make_spec(params)
    num_failures = params[:num_failures] or
      raise ArgumentError, "expected :num_failures parameter"

    source = "describe 'test' do\n"
    (0...2).map do |i|
      if i < num_failures
        source << "  it('#{i}') { expect(1).to == 2 }\n"
      else
        source << "  it('#{i}') {}\n"
      end
    end
    source << "end"
    open(spec_path, 'w') { |f| f.puts source }
  end

  def spec_path
    "#{TMP}/test_spec.rb"
  end

  it "should let you rerun failing specs until they all pass" do
    Dir.chdir tmp do
      make_spec(:num_failures => 2)
      status, output = respec(spec_path)
      expect(status).to_not be_success
      expect(output).to include('2 examples, 2 failures')

      make_spec(:num_failures => 1)
      status, output = respec("#{spec_path} f")
      expect(status).to_not be_success
      expect(output).to include('2 examples, 1 failure')

      make_spec(:num_failures => 0)
      status, output = respec("#{spec_path} f")
      expect(status).to be_success
      expect(output).to include('1 example, 0 failures')
    end
  end
end
