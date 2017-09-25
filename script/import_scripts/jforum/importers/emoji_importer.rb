module ImportScripts::JForum
  class EmojiImporter
    # @param database [ImportScripts::JForum::Database_3_0 | ImportScripts::JForum::Database_3_1]
    # @param uploader [ImportScripts::Uploader]
    # @param settings [ImportScripts::JForum::Settings]
    def initialize(database, uploader, settings)
      @database = database
      @uploader = uploader

      # TODO morn setting
      @smilies_path = File.join(settings.base_dir, "images/smilies")
    end

    # Creates an emoji upload.
    # Expects path to be the full path and filename of the source file.
    # @return [Upload]
    def create_custom_emoji_upload(path, source_filename)
      tmp = Tempfile.new('discourse-upload')
      src = File.open(path)
      FileUtils.copy_stream(src, tmp)
      src.close
      tmp.rewind

      UploadCreator.new(tmp, source_filename, type: 'custom_emoji').create_for(Discourse::SYSTEM_USER_ID)
    rescue => e
      Rails.logger.error("Failed to create custom emoji upload: #{e}")
      nil
    ensure
      tmp.close rescue nil
      tmp.unlink rescue nil
    end

    def import_emoji(row)
      emoji = row[:code].gsub!(/^:(.*):$/, '\1')

      if emoji.blank?
        puts "Skipped #{row[:code]}, because it's not an emoji"
        return
      end

      existing = CustomEmoji.where("LOWER(name) = ?", emoji.downcase).first
      if existing
        puts "Skipped :#{emoj}:, because it's already existing"
        return
      end

      filename = row[:disk_name]
      path = File.join(@smilies_path, filename)
      upload = create_custom_emoji_upload(path, filename)

      if upload.nil? || !upload.persisted?
        puts "Failed to upload #{path}"
        puts upload.errors.inspect if upload
      else
        new_customemoji = CustomEmoji.new(
          name: emoji,
          upload: upload
        )
        new_customemoji.save!
        new_customemoji
      end
    end
  end
end
