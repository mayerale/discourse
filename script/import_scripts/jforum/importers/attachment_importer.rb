module ImportScripts::JForum
  class AttachmentImporter
    # @param database [ImportScripts::JForum::Database_2_1]
    # @param uploader [ImportScripts::Uploader]
    # @param settings [ImportScripts::JForum::Settings]
    def initialize(database, uploader, settings)
      @database = database
      @uploader = uploader

      @attachment_path = File.join(settings.base_dir, Constants::SUBDIR_UPLOAD)
    end

    def import_attachments(user_id, post_id, topic_id = 0)
      rows = @database.fetch_attachments(topic_id, post_id)
      return nil if rows.size < 1

      attachments = []

      rows.each do |row|
        path = File.join(@attachment_path, row[:physical_filename])
        filename = CGI.unescapeHTML(row[:real_filename])
        upload = @uploader.create_upload(user_id, path, filename)

        if upload.nil? || !upload.persisted?
          puts "Failed to upload #{path}"
          puts upload.errors.inspect if upload
        else
          attachments << @uploader.html_for_upload(upload, filename)
        end
      end

      attachments
    end
  end
end
