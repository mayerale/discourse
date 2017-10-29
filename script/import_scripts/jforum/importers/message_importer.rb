module ImportScripts::JForum
  class MessageImporter
    # @param database [ImportScripts::JForum::Database_2_1]
    # @param lookup [ImportScripts::LookupContainer]
    # @param text_processor [ImportScripts::JForum::TextProcessor]
    # @param attachment_importer [ImportScripts::JForum::AttachmentImporter]
    # @param settings [ImportScripts::JForum::Settings]
    def initialize(database, lookup, text_processor, attachment_importer, settings)
      @database = database
      @lookup = lookup
      @text_processor = text_processor
      @attachment_importer = attachment_importer
      @settings = settings
    end

    def map_to_import_ids(rows)
      rows.map { |row| get_import_id(row[:privmsgs_id]) }
    end

    def map_message(row)
      user_id = @lookup.user_id_from_imported_user_id(row[:privmsgs_from_userid]) || Discourse.system_user.id

      mapped = {
        id: get_import_id(row[:privmsgs_id]),
        user_id: user_id,
        created_at: Time.zone.at(row[:privmsgs_date]),
        raw: @text_processor.process_private_msg(row[:privmsgs_text], nil)
      }

      current_user_ids = sorted_user_ids(row[:privmsgs_from_userid], row[:privmsgs_to_userid])
      topic_id = find_topic_id(row, current_user_ids)

      if topic_id.blank?
        map_first_message(row, current_user_ids, mapped)
      else
        map_other_message(row, topic_id, mapped)
      end
    end

    protected

    def map_first_message(row, current_user_ids, mapped)
      mapped[:title] = get_topic_title(row)
      mapped[:archetype] = Archetype.private_message
      mapped[:target_usernames] = get_recipient_usernames(row)
      mapped[:custom_fields] = { import_key: get_topic_key(row, current_user_ids) }

      if mapped[:target_usernames].empty?
        puts "Private message without recipients. Skipping #{row[:privmsgs_id]}: #{row[:privmsgs_subject][0..40]}"
        return nil
      end

      mapped
    end

    def map_other_message(row, topic_id, mapped)
      mapped[:topic_id] = topic_id
      mapped
    end

    def get_recipient_usernames(row)
      import_user_ids = [ row[:privmsgs_to_userid] ]

      import_user_ids.map! do |import_user_id|
        @lookup.find_user_by_import_id(import_user_id).try(:username)
      end.compact
    end

    def get_topic_title(row)
      CGI.unescapeHTML(row[:privmsgs_subject]).gsub(/^(Aw:|Re:)+/i, "")
    end

    def get_import_id(msg_id)
      "pm:#{msg_id}"
    end

    # Creates a sorted array consisting of the message's author and recipient.
    def sorted_user_ids(author_id, to_address)
      user_ids = []
      user_ids << to_address unless to_address.nil?
      user_ids << author_id unless author_id.nil?
      user_ids.uniq!
      user_ids.sort!
    end

    # Tries to create a key for a private message thread.
    # Since discourse could change the title, we use also the title.
    def get_topic_key(row, current_user_ids)
      "#{current_user_ids.join(',')};#{get_topic_title(row)}"
    end

    # Tries to find a Discourse topic (private message) that has the same title as the current message.
    # The users involved in these messages must match too.
    def find_topic_id(row, current_user_ids)
      topic_title = get_topic_title(row)

      Post.select(:topic_id)
        .joins(:topic)
        .joins(:_custom_fields)
        .where(["post_custom_fields.name = 'import_key' AND post_custom_fields.value = :key",
                { key: get_topic_key(row, current_user_ids) }])
        .order('topics.created_at DESC')
        .first.try(:topic_id)
    end
  end
end
