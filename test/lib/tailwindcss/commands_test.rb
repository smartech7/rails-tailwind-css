require "test_helper"
require "minitest/mock"

class Tailwindcss::CommandsTest < ActiveSupport::TestCase
  def mock_exe_directory(platform)
    Dir.mktmpdir do |dir|
      FileUtils.mkdir(File.join(dir, platform))
      path = File.join(dir, platform, "tailwindcss")
      FileUtils.touch(path)
      Gem::Platform.stub(:match, true) do
        yield(dir, path)
      end
    end
  end

  def mock_local_tailwindcss_install
    Dir.mktmpdir do |dir|
      path = File.join(dir, "tailwindcss")
      FileUtils.touch(path)
      yield(dir, path)
    end
  end

  test ".platform is a string containing just the cpu and os (not the version)" do
    expected = "#{Gem::Platform.local.cpu}-#{Gem::Platform.local.os}"
    assert_equal(expected, Tailwindcss::Commands.platform)
  end

  test ".executable returns the absolute path to the binary" do
    mock_exe_directory("sparc-solaris2.8") do |dir, executable|
      expected = File.expand_path(File.join(dir, "sparc-solaris2.8", "tailwindcss"))
      assert_equal(expected, executable, "assert on setup")
      assert_equal(expected, Tailwindcss::Commands.executable(exe_path: dir))
    end
  end

  test ".executable raises UnsupportedPlatformException when we're not on a supported platform" do
    Gem::Platform.stub(:match, false) do # nothing is supported
      assert_raises(Tailwindcss::Commands::UnsupportedPlatformException) do
        Tailwindcss::Commands.executable
      end
    end
  end

  test ".executable raises ExecutableNotFoundException when we can't find the executable we expect" do
    Dir.mktmpdir do |dir| # empty directory
      assert_raises(Tailwindcss::Commands::ExecutableNotFoundException) do
        Tailwindcss::Commands.executable(exe_path: dir)
      end
    end
  end

  test ".executable returns the executable in TAILWINDCSS_INSTALL_DIR when no packaged binary exists" do
    mock_local_tailwindcss_install do |local_install_dir, expected|
      result = nil
      begin
        ENV["TAILWINDCSS_INSTALL_DIR"] = local_install_dir
        assert_output(nil, /using TAILWINDCSS_INSTALL_DIR/) do
          result = Tailwindcss::Commands.executable(exe_path: "/does/not/exist")
        end
      ensure
        ENV["TAILWINDCSS_INSTALL_DIR"] = nil
      end
      assert_equal(expected, result)
    end
  end

  test ".executable returns the executable in TAILWINDCSS_INSTALL_DIR when we're not on a supported platform" do
    Gem::Platform.stub(:match, false) do # nothing is supported
      mock_local_tailwindcss_install do |local_install_dir, expected|
        result = nil
        begin
          ENV["TAILWINDCSS_INSTALL_DIR"] = local_install_dir
          assert_output(nil, /using TAILWINDCSS_INSTALL_DIR/) do
            result = Tailwindcss::Commands.executable
          end
        ensure
          ENV["TAILWINDCSS_INSTALL_DIR"] = nil
        end
        assert_equal(expected, result)
      end
    end
  end

  test ".executable returns the executable in TAILWINDCSS_INSTALL_DIR even when a packaged binary exists" do
    mock_exe_directory("sparc-solaris2.8") do |dir, _executable|
      mock_local_tailwindcss_install do |local_install_dir, expected|
        result = nil
        begin
          ENV["TAILWINDCSS_INSTALL_DIR"] = local_install_dir
          assert_output(nil, /using TAILWINDCSS_INSTALL_DIR/) do
            result = Tailwindcss::Commands.executable(exe_path: dir)
          end
        ensure
          ENV["TAILWINDCSS_INSTALL_DIR"] = nil
        end
        assert_equal(expected, result)
      end
    end
  end

  test ".executable raises ExecutableNotFoundException is TAILWINDCSS_INSTALL_DIR is set to a nonexistent dir" do
    begin
      ENV["TAILWINDCSS_INSTALL_DIR"] = "/does/not/exist"
      assert_raises(Tailwindcss::Commands::DirectoryNotFoundException) do
        Tailwindcss::Commands.executable
      end
    ensure
      ENV["TAILWINDCSS_INSTALL_DIR"] = nil
    end
  end

  test ".compile_command" do
    mock_exe_directory("sparc-solaris2.8") do |dir, executable|
      Rails.stub(:root, File) do # Rails.root won't work in this test suite
        actual = Tailwindcss::Commands.compile_command(exe_path: dir)
        assert_kind_of(Array, actual)
        assert_equal(executable, actual.first)
        assert_includes(actual, "--minify")

        actual = Tailwindcss::Commands.compile_command(exe_path: dir, debug: true)
        assert_kind_of(Array, actual)
        assert_equal(executable, actual.first)
        refute_includes(actual, "--minify")
      end
    end
  end

  test ".compile_command when Rails compression is on" do
    mock_exe_directory("sparc-solaris2.8") do |dir, executable|
      Rails.stub(:root, File) do # Rails.root won't work in this test suite
        Tailwindcss::Commands.stub(:rails_css_compressor?, true) do
          actual = Tailwindcss::Commands.compile_command(exe_path: dir)
          assert_kind_of(Array, actual)
          refute_includes(actual, "--minify")
        end

        Tailwindcss::Commands.stub(:rails_css_compressor?, false) do
          actual = Tailwindcss::Commands.compile_command(exe_path: dir)
          assert_kind_of(Array, actual)
          assert_includes(actual, "--minify")
        end
      end
    end
  end

  test ".watch_command" do
    mock_exe_directory("sparc-solaris2.8") do |dir, executable|
      Rails.stub(:root, File) do # Rails.root won't work in this test suite
        actual = Tailwindcss::Commands.watch_command(exe_path: dir)
        assert_kind_of(Array, actual)
        assert_equal(executable, actual.first)
        assert_includes(actual, "-w")
        refute_includes(actual, "-p")
        assert_includes(actual, "--minify")

        actual = Tailwindcss::Commands.watch_command(exe_path: dir, debug: true)
        assert_kind_of(Array, actual)
        assert_equal(executable, actual.first)
        assert_includes(actual, "-w")
        refute_includes(actual, "-p")
        refute_includes(actual, "--minify")

        actual = Tailwindcss::Commands.watch_command(exe_path: dir, poll: true)
        assert_kind_of(Array, actual)
        assert_equal(executable, actual.first)
        assert_includes(actual, "-w")
        refute_includes(actual, "always")
        assert_includes(actual, "-p")
        assert_includes(actual, "--minify")

        actual = Tailwindcss::Commands.watch_command(exe_path: dir, always: true)
        assert_kind_of(Array, actual)
        assert_equal(executable, actual.first)
        assert_includes(actual, "-w")
        assert_includes(actual, "always")
      end
    end
  end
end
