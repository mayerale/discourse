module ImportScripts::JForum
  class TextProcessor
    # @param lookup [ImportScripts::LookupContainer]
    # @param database [ImportScripts::JForum::Database_2_1]
    # @param smiley_processor [ImportScripts::JForum::SmileyProcessor]
    # @param settings [ImportScripts::JForum::Settings]
    def initialize(lookup, database, smiley_processor, settings)
      @lookup = lookup
      @database = database
      @smiley_processor = smiley_processor

      @settings = settings
      @new_site_prefix = settings.new_site_prefix
      create_internal_link_regexps(settings.original_site_prefix)
    end

    def process_raw_text(raw)
      text = raw.dup
      text = CGI.unescapeHTML(text)

      escape_markdown(text) if @settings.escape_markdown

      if @settings.use_bbcode_to_md
        text = bbcode_to_md(text)
      end
      process_smilies(text)
      process_links(text)
      process_lists(text)
      process_quotes(text)
      process_size(text)

      text
    end

    def process_post(raw, attachments)
      text = process_raw_text(raw)
      text = process_attachments(text, attachments) if attachments.present?
      text
    end

    def process_private_msg(raw, attachments)
      text = process_raw_text(raw)
      text
    end

    protected

    def bbcode_to_md(text)
      begin
        text.bbcode_to_md(false)
      rescue => e
        puts "Problem converting \n#{text}\n using ruby-bbcode-to-md"
        text
      end
    end

    def process_smilies(text)
      @smiley_processor.replace_smilies(text)
    end

    def process_links(text)
      text.gsub!(@internal_link_regexp) do |link|
        replace_internal_link(link, $1, $2)
      end
    end

    # Bbcode [size] doesn't work, so we just remove it
    def process_size(text)
      text.gsub!(/\[size.*?\](.*?)\[\/size\]/mi, '\1')
    end

    # Escape text looking like markdown
    def escape_markdown(text)
      text.gsub!(/(^|\n)([-*>#_`])/mi, '\1\\\\\\2')
      text.gsub!(/(^|\n)([0-9]*?)\. /mi, '\1\2\\. ')
    end

    def replace_internal_link(link, import_topic_id, import_post_id)
      if import_post_id.nil?
        replace_internal_topic_link(link, import_topic_id)
      else
        replace_internal_post_link(link, import_post_id)
      end
    end

    def replace_internal_topic_link(link, import_topic_id)
      import_post_id = @database.get_first_post_id(import_topic_id)
      return link if import_post_id.nil?

      replace_internal_post_link(link, import_post_id)
    end

    def replace_internal_post_link(link, import_post_id)
      topic = @lookup.topic_lookup_from_imported_post_id(import_post_id)
      topic ? "#{@new_site_prefix}#{topic[:url]}" : link
    end

    # converts list tags to markdown lists (bbcode-to-md doesn't recognize it)
    def process_lists(text)
      text.gsub!(/(\n)*?\[list\](.*?)\[\/list\](\n)*?/mi, "\n- \\2\n")
    end

    def process_quotes(text)
      # JForum has a more flexible bbcode syntax, Discourse is more strict
      text.gsub!(/(\[quote.*?\])/mi, "\n\\1\n")
      text.gsub!(/(\[\/quote\])/mi, "\n\\1\n")
    end

    # This appends attachments to the end of the text.
    def process_attachments(text, attachments)
      unreferenced_attachments = attachments.dup
      unreferenced_attachments = unreferenced_attachments.compact
      text << "\n" << unreferenced_attachments.join("\n") unless unreferenced_attachments.empty?
      text
    end

    def create_internal_link_regexps(original_site_prefix)
      host = original_site_prefix.gsub('.', '\.')
      link_regex = "http(?:s)?:\\/\\/#{host}\\/(?:\\S*)(?:posts\\/list\\/(?:\\d+\\/)?(\\d+).page(?:#(\\d+))?)"
      @internal_link_regexp = Regexp.new(link_regex, Regexp::IGNORECASE)
    end
  end
end
