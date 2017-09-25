require_relative 'attachment_importer'
require_relative 'avatar_importer'
require_relative 'bookmark_importer'
require_relative 'category_importer'
require_relative 'message_importer'
require_relative 'poll_importer'
require_relative 'post_importer'
require_relative 'permalink_importer'
require_relative 'user_importer'
require_relative 'emoji_importer'
require_relative '../support/smiley_processor'
require_relative '../support/text_processor'

module ImportScripts::JForum
  class ImporterFactory
    # @param database [ImportScripts::JForum::Database_3_0 | ImportScripts::JForum::Database_3_1]
    # @param lookup [ImportScripts::LookupContainer]
    # @param uploader [ImportScripts::Uploader]
    # @param settings [ImportScripts::JForum::Settings]
    # @param phpbb_config [Hash]
    def initialize(database, lookup, uploader, settings)
      @database = database
      @lookup = lookup
      @uploader = uploader
      @settings = settings
    end

    def user_importer
      UserImporter.new(avatar_importer, @settings)
    end

    def category_importer
      CategoryImporter.new(@lookup, text_processor, permalink_importer)
    end

    def post_importer
      PostImporter.new(@lookup, text_processor, attachment_importer, poll_importer, permalink_importer, @settings)
    end

    def message_importer
      MessageImporter.new(@database, @lookup, text_processor, attachment_importer, @settings)
    end

    def bookmark_importer
      BookmarkImporter.new
    end

    def permalink_importer
      @permalink_importer ||= PermalinkImporter.new(@settings.permalinks)
    end

    def emoji_importer
      EmojiImporter.new(@database, @lookup, @settings)
    end

    protected

    def attachment_importer
      AttachmentImporter.new(@database, @uploader, @settings)
    end

    def avatar_importer
      AvatarImporter.new(@uploader, @settings)
    end

    def poll_importer
      PollImporter.new(@lookup, @database, text_processor)
    end

    def text_processor
      @text_processor ||= TextProcessor.new(@lookup, @database, smiley_processor, @settings)
    end

    def smiley_processor
      SmileyProcessor.new(@uploader, @settings)
    end
  end
end
