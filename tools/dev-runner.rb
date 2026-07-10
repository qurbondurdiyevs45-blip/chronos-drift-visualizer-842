#!/usr/bin/env ruby

require 'fileutils'
require 'optparse'
require 'json'

class ChronosDevRunner
  COMPONENTS = {
    rust_core: { dir: 'core/ntp-engine', build: 'cargo build --release' },
    web_ui: { dir: 'ui/web', build: 'npm install && npm run build' },
    mobile: { dir: 'ui/mobile', build: 'flutter pub get' }
  }

  def initialize
    @options = {}
    parse_options
  end

  def parse_options
    OptionParser.new do |opts|
      opts.banner = "Usage: tools/dev-runner.rb [options]"

      opts.on("-b", "--build COMPONENT", "Build a specific component (core, ui, mobile, all)") do |c|
        @options[:build] = c
      end

      opts.on("-s", "--setup", "Install all dependencies across all language runtimes") do
        @options[:setup] = true
      end

      opts.on("-r", "--run", "Run the Chronos Drift Visualizer in dev mode") do
        @options[:run] = true
      end

      opts.on("-h", "--help", "Prints this help") do
        puts opts
        exit
      end
    end.parse!
  end

  def log(msg)
    puts "\e[34m[Chronos Build]\e[0m #{msg}"
  end

  def error(msg)
    puts "\e[31m[Error]\e[0m #{msg}"
    exit 1
  end

  def check_environment
    log "Checking environment dependencies..."
    system('rustc --version > /dev/null') || error("Rust not found")
    system('node -v > /dev/null') || error("Node.js not found")
    system('flutter --version > /dev/null') || error("Flutter not found")
  end

  def setup_all
    log "Initializing project dependencies..."
    
    Dir.chdir('core/ntp-engine') do
      log "Fetching Rust crates..."
      system('cargo fetch')
    end

    Dir.chdir('ui/web') do
      log "Installing NPM packages..."
      system('npm install')
    end

    Dir.chdir('ui/mobile') do
      log "Cleaning and fetching Flutter packages..."
      system('flutter pub get')
    end
    
    log "Setup complete."
  end

  def build_component(name)
    case name
    when 'core'
      log "Building Rust NTP Engine..."
      Dir.chdir(COMPONENTS[:rust_core][:dir]) { system(COMPONENTS[:rust_core][:build]) }
    when 'ui'
      log "Building Web Frontend..."
      Dir.chdir(COMPONENTS[:web_ui][:dir]) { system(COMPONENTS[:web_ui][:build]) }
    when 'all'
      COMPONENTS.each_key { |k| build_component(k.to_s.gsub('_core', '').gsub('rust_', '')) }
    else
      error "Unknown component: #{name}"
    end
  end

  def run_dev
    log "Starting Chronos Drift Visualizer Service..."
    # Ensure core is built before running
    build_component('core')
    
    # Check OS to handle cross-platform paths
    ext = Gem::win_platform? ? '.exe' : ''
    binary_path = File.join(Dir.pwd, "core/ntp-engine/target/release/ntp-engine#{ext}")
    
    if File.exist?(binary_path)
      spawn("#{binary_path} --server 127.0.0.1:8080")
      log "NTP Engine running on port 8080"
    else
      error "Engine binary not found. Build failed."
    end

    log "Starting Web UI Development Server..."
    Dir.chdir('ui/web') do
      exec('npm run dev')
    end
  end

  def execute
    check_environment
    
    if @options[:setup]
      setup_all
    elsif @options[:build]
      build_component(@options[:build])
    elsif @options[:run]
      run_dev
    else
      puts "No command provided. Use --help for usage."
    end
  end
end

runner = ChronosDevRunner.new
runner.execute