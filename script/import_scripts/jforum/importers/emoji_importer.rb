module ImportScripts::JForum
  class EmojiImporter
    # @param database [ImportScripts::JForum::Database_3_0 | ImportScripts::JForum::Database_3_1]
    # @param uploader [ImportScripts::Uploader]
    # @param settings [ImportScripts::JForum::Settings]
    def initialize(database, uploader, smiley_processor, settings)
      @database = database
      @uploader = uploader
      @smiley_processor = smiley_processor

      # TODO morn settings: path + use mapping?
      @smilies_path = File.join(settings.base_dir, "images/smilies")
    end

    def import_emoji(emoji, filename)
      if @smiley_processor.has_smiley?(emoji)
        puts "Skipping #{emoji}, because it has a default mapping"
        return
      end

      emoji_name = emoji.gsub(/^:(.*):$/, '\1')

      if emoji_name.blank?
        puts "Skipping #{emoji}, because it's not an emoji"
        return
      end

      existing = CustomEmoji.where("LOWER(name) = ?", emoji_name.downcase).first
      if existing
        puts "Skipping #{emoji}, because it's already existing"
        return
      end

      path = File.join(@smilies_path, filename)
      upload = @uploader.create_upload(Discourse::SYSTEM_USER_ID, path, filename)

      if upload.nil? || !upload.persisted?
        puts "Failed to upload #{path}"
        puts upload.errors.inspect if upload
      else
        new_customemoji = CustomEmoji.new(
          name: emoji_name,
          upload: upload
        )
        new_customemoji.save!
        new_customemoji
      end
    end
  end
end
