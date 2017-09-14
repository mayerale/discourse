# Importer for JForum

if ARGV.length != 1 || !File.exists?(ARGV[0])
  STDERR.puts '', 'Usage of JForum importer:', 'bundle exec ruby jforum.rb <path/to/settings.yml>'
  STDERR.puts '', "Use the settings file from #{File.expand_path('jforum/settings.yml', File.dirname(__FILE__))} as an example."
  exit 1
end

module ImportScripts
  module JForum
    require_relative 'jforum/support/settings'
    require_relative 'jforum/database/database'

    @settings = Settings.load(ARGV[0])

    # We need to load the gem files for ruby-bbcode-to-md and the database adapter
    # (e.g. mysql2) before bundler gets initialized by the base importer.
    # Otherwise we get an error since those gems are not always in the Gemfile.
    require 'ruby-bbcode-to-md' if @settings.use_bbcode_to_md

    begin
      @database = Database.create(@settings.database)
    rescue UnsupportedVersionError => error
      STDERR.puts '', error.message
      exit 1
    end

    require_relative 'jforum/importer'
    Importer.new(@settings, @database).perform
  end
end
