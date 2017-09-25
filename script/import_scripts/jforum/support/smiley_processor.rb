module ImportScripts::JForum
  class SmileyProcessor
    # @param uploader [ImportScripts::Uploader]
    # @param settings [ImportScripts::JForum::Settings]
    def initialize(uploader, settings)
      @uploader = uploader
      # TODO morn setting
      @smilies_path = File.join(settings.base_dir, "images/smilies")

      @smiley_map = {}
      add_default_smilies
      add_configured_smilies(settings.emojis)
    end

    def replace_smilies(text)
      @smiley_map.each do |smiley, emoji|
        text.gsub!(/#{Regexp.quote(smiley)}/, emoji)
      end
    end

    def has_smiley?(smiley)
      @smiley_map.has_key?(smiley)
    end

    protected

    def add_default_smilies
      {
        # these emojis are also supported as translations by discourse
        [':D', ':-D', ':grin:'] => ':smiley:',
        [':)', ':-)', ':smile:'] => ':slight_smile:',
        [';)', ';-)', ':wink:'] => ':wink:',
        [':(', ':-(', ':sad:'] => ':frowning:',
        [':P', ':-P', ':razz:'] => ':stuck_out_tongue:',
        [':|', ':-|'] => ':neutral_face:',

        # these emojis are default smilies from JForum
        [':o', ':-o', ':eek:'] => ':astonished:',
        [':shock:'] => ':open_mouth:',
        [':?', ':-?', ':???:'] => ':confused:',
        ['8-)', '8)', ':cool:'] => ':sunglasses:',
        [':lol:'] => ':laughing:',
        [':x', ':-x', ':mad:'] => ':angry:',
        [':oops:'] => ':blush:',
        [':cry:'] => ':cry:',
        [':evil:'] => ':imp:',
        [':twisted:'] => ':smiling_imp:',
        [':roll:'] => ':unamused:',
        [':!:'] => ':exclamation:',
        [':?:', ':?'] => ':question:',
        [':idea:'] => ':bulb:',
        [':arrow:'] => ':arrow_right:',
      }.each do |smilies, emoji|
        smilies.each { |smiley| @smiley_map[smiley] = emoji }
      end
    end

    def add_configured_smilies(emojis)
      return if emojis.nil?
      emojis.each do |emoji, smilies|
        Array.wrap(smilies)
          .each { |smiley| @smiley_map[smiley] = ":#{emoji}:" }
      end
    end
  end
end
