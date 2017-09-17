module ImportScripts::JForum
  class MessageImporter
    # @param database [ImportScripts::JForum::Database_3_0 | ImportScripts::JForum::Database_3_1]
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

    # MIGRATED morn
    def map_to_import_ids(rows)
      rows.map { |row| get_import_id(row[:privmsgs_id]) }
    end

    # MIGRATED morn
    def map_message(row)
      user_id = @lookup.user_id_from_imported_user_id(row[:privmsgs_from_userid]) || Discourse.system_user.id
      # attachments = import_attachments(row, user_id)

      mapped = {
        id: get_import_id(row[:privmsgs_id]),
        user_id: user_id,
        created_at: Time.zone.at(row[:privmsgs_date]),
        raw: @text_processor.process_private_msg(row[:privmsgs_text], nil)
      }

      current_user_ids = sorted_user_ids(row[:privmsgs_from_userid], row[:privmsgs_to_userid])
      topic_id = get_topic_id(row, current_user_ids)

      if topic_id.blank?
        map_first_message(row, current_user_ids, mapped)
      else
        map_other_message(row, topic_id, mapped)
      end
    end

    protected

    # MIGRATED morn
    def map_first_message(row, current_user_ids, mapped)
      mapped[:title] = get_topic_title(row)
      mapped[:archetype] = Archetype.private_message
      mapped[:target_usernames] = get_recipient_usernames(row)
      normalized_title = mapped[:title].gsub(/^(Aw:)+/i, "")
      mapped[:custom_fields] = { import_user_ids: current_user_ids.join(',')+";"+normalized_title }

      if mapped[:target_usernames].empty?
        puts "Private message without recipients. Skipping #{row[:privmsgs_id]}: #{row[:privmsgs_subject][0..40]}"
        return nil
      end

      mapped
    end

    # MIGRATED morn
    def map_other_message(row, topic_id, mapped)
      mapped[:topic_id] = topic_id
      mapped
    end

    # def get_recipient_user_ids(to_address)
    #   return [] if to_address.blank?
    #
    #   # to_address looks like this: "u_91:u_1234:u_200"
    #   # The "u_" prefix is discarded and the rest is a user_id.
    #   user_ids = to_address.split(':')
    #   user_ids.uniq!
    #   user_ids.map! { |u| u[2..-1].to_i }
    # end

    # MIGRATED morn
    def get_recipient_usernames(row)
      import_user_ids = [ row[:privmsgs_to_userid] ]

      import_user_ids.map! do |import_user_id|
        @lookup.find_user_by_import_id(import_user_id).try(:username)
      end.compact
    end

    # MIGRATED morn
    def get_topic_title(row)
      CGI.unescapeHTML(row[:privmsgs_subject])
    end

    # MIGRATED morn
    def get_import_id(msg_id)
      "pm:#{msg_id}"
    end

    # MIGRATED morn
    # Creates a sorted array consisting of the message's author and recipients.
    def sorted_user_ids(author_id, to_address)
      user_ids = []
      # get_recipient_user_ids(to_address)
      user_ids << to_address unless to_address.nil?
      user_ids << author_id unless author_id.nil?
      user_ids.uniq!
      user_ids.sort!
    end

    # TODO morn replace with find_topic_id
    def get_topic_id(row, current_user_ids)
      ret = find_topic_id(row, current_user_ids)
      # puts "#{row[:privmsgs_subject]}: [#{ret}]"
      ret
    end

    # MIGRATED morn
    # Tries to find a Discourse topic (private message) that has the same title as the current message.
    # The users involved in these messages must match too.
    def find_topic_id(row, current_user_ids)
      topic_title = get_topic_title(row).gsub(/^(Aw:)+/i, "")

      Post.select(:topic_id)
        .joins(:topic)
        .joins(:_custom_fields)
        .where(["post_custom_fields.name = 'import_user_ids' AND post_custom_fields.value = :user_ids",
                { user_ids: current_user_ids.join(',')+";"+topic_title }])
        .order('topics.created_at DESC')
        .first.try(:topic_id)
    end
  end
end
