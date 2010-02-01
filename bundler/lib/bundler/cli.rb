$:.unshift File.expand_path('../vendor', __FILE__)
require 'thor'
require 'bundler'
require 'rubygems/config_file'

# Work around a RubyGems bug
Gem.configuration

module Bundler
  class CLI < Thor
    ARGV = ::ARGV.dup

    def self.banner(task)
      task.formatted_usage(self, false)
    end

    desc "init", "Generates a Gemfile into the current working directory"
    def init
      if File.exist?("Gemfile")
        puts "Gemfile already exists at `#{Dir.pwd}/Gemfile`"
      else
        puts "Writing new Gemfile to `#{Dir.pwd}/Gemfile`"
        FileUtils.cp(File.expand_path('../templates/Gemfile', __FILE__), 'Gemfile')
      end
    end

    def initialize(*)
      super
      Bundler.ui = UI::Shell.new(shell)
      Gem::DefaultUserInteraction.ui = UI::RGProxy.new(Bundler.ui)
    end

    desc "check", "Checks if the dependencies listed in Gemfile are satisfied by currently installed gems"
    def check
      with_rescue do
        env = Bundler.load
        # Check top level dependencies
        missing = env.dependencies.select { |d| env.index.search(d).empty? }
        if missing.any?
          puts "The following dependencies are missing"
          missing.each do |d|
            puts "  * #{d}"
          end
        else
          env.specs
          puts "The Gemfile's dependencies are satisfied"
        end
      end
    rescue VersionConflict => e
      puts e.message
    end

    desc "install", "Install the current environment to the system"
    method_option :without, :type => :array, :banner => "Exclude gems thar are part of the specified named group"
    def install
      opts = options.dup
      opts[:without] ||= []
      opts[:without].map! { |g| g.to_sym }

      Installer.install(Bundler.root, Bundler.definition, opts)
    rescue Bundler::GemNotFound => e
      puts e.message
      exit 1
    end

    desc "lock", "Locks a resolve"
    def lock
      environment = Bundler.load
      environment.lock
    end

    desc "pack", "Packs all the gems to vendor/cache"
    def pack
      environment = Bundler.load
      environment.pack
    end

    desc "exec", "Run the command in context of the bundle"
    def exec(*)
      ARGV.delete('exec')
      ENV["RUBYOPT"] = %W(
        -I#{File.expand_path('../..', __FILE__)}
        -rbundler/setup
        #{ENV["RUBYOPT"]}
      ).compact.join(' ')
      Kernel.exec *ARGV
    end

  private

    def with_rescue
      yield
    rescue GemfileNotFound => e
      puts e.message
      exit 1
    end
  end
end