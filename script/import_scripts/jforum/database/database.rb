require 'mysql2'
require_relative 'database_2_1'

module ImportScripts::JForum
  class Database
    # @param database_settings [ImportScripts::JForum::DatabaseSettings]
    def self.create(database_settings)
      Database.new(database_settings).create_database
    end

    # @param database_settings [ImportScripts::JForum::DatabaseSettings]
    def initialize(database_settings)
      @database_settings = database_settings
      @database_client = create_database_client
    end

    # @return [ImportScripts::JForum::Database_2_1]
    def create_database
      Database_2_1.new(@database_client, @database_settings)
    end

    protected

    def create_database_client
      Mysql2::Client.new(
        host: @database_settings.host,
        port: @database_settings.port,
        username: @database_settings.username,
        password: @database_settings.password,
        database: @database_settings.schema,
        reconnect: true
      )
    end

    class UnsupportedVersionError < RuntimeError;
    end
  end
end
