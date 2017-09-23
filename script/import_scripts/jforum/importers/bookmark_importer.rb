# MIGRATED morn

module ImportScripts::JForum
  class BookmarkImporter
    def map_bookmark(row)
      {
        user_id: row[:user_id],
        post_id: row[:post_id]
      }
    end
  end
end
