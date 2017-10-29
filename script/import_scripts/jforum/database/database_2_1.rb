require_relative 'database_base'
require_relative '../support/constants'

module ImportScripts::JForum
  class Database_2_1 < DatabaseBase
    def count_users
      count(<<-SQL)
        SELECT COUNT(*) AS count
        FROM #{@table_prefix}users u
      SQL
    end

    def fetch_users(last_user_id)
      query(<<-SQL, :user_id)
        SELECT DISTINCT u.user_id, u.user_email, u.username, u.user_password, u.user_regdate, u.user_lastvisit,
          u.user_active, g.group_id, g.group_name, b.user_id ban_userid,
          u.user_posts, u.user_website, u.user_from, u.user_biography, u.user_avatar_type, u.user_avatar
        FROM #{@table_prefix}users u
          LEFT OUTER JOIN #{@table_prefix}user_groups ug ON (ug.user_id = u.user_id)
          LEFT OUTER JOIN #{@table_prefix}groups g ON (g.group_id = ug.group_id)
          LEFT OUTER JOIN #{@table_prefix}banlist b ON (
            u.user_id = b.user_id
          )
        WHERE u.user_id > #{last_user_id}
        ORDER BY u.user_id
        LIMIT #{@batch_size}
      SQL
    end

    def fetch_categories
      # discourse category = jforum forum

      query(<<-SQL)
        SELECT f.forum_id, f.forum_name, f.forum_desc, x.first_post_time
        FROM #{@table_prefix}forums f
          LEFT OUTER JOIN (
            SELECT MIN(topic_time) AS first_post_time, forum_id
            FROM #{@table_prefix}topics
            GROUP BY forum_id
          ) x ON (f.forum_id = x.forum_id)
        ORDER BY f.forum_id
      SQL
    end

    def count_posts
      count(<<-SQL)
        SELECT COUNT(*) AS count
        FROM #{@table_prefix}posts
      SQL
    end

    def fetch_posts(last_post_id)
      # TODO morn t.poll_mx_options)

      query(<<-SQL, :post_id)
        SELECT p.post_id, p.topic_id, p.user_id poster_id,
          p.post_time, p.attach,
          pt.post_text,
          t.forum_id, t.topic_title, t.topic_first_post_id,
          t.topic_status, t.topic_type, t.topic_views,
          v.vote_text, v.vote_start, v.vote_length
        FROM #{@table_prefix}posts p
          JOIN #{@table_prefix}topics t ON (p.topic_id = t.topic_id)
          JOIN #{@table_prefix}posts_text pt ON (pt.post_id = p.post_id)
          LEFT OUTER JOIN #{@table_prefix}vote_desc v ON (v.topic_id = t.topic_id)
        WHERE p.post_id > #{last_post_id}
        ORDER BY p.post_id
        LIMIT #{@batch_size}
      SQL
    end

    def get_first_post_id(topic_id)
      query(<<-SQL).try(:first).try(:[], :topic_first_post_id)
        SELECT topic_first_post_id
        FROM #{@table_prefix}topics
        WHERE topic_id = #{topic_id}
      SQL
    end

    def fetch_poll_options(topic_id)
      query(<<-SQL)
        SELECT o.vote_option_id, o.vote_option_text, o.vote_result AS anonymous_votes
        FROM #{@table_prefix}vote_results o
          JOIN #{@table_prefix}vote_desc v ON (v.vote_id = o.vote_id)
          JOIN #{@table_prefix}topics t ON (v.topic_id = t.topic_id)
        WHERE t.topic_id = #{topic_id}
        ORDER BY o.vote_option_id
      SQL
    end

    def get_voters(topic_id)
      query(<<-SQL).first
        SELECT SUM(r.vote_result) AS anonymous_voters
        FROM #{@table_prefix}vote_results r
          JOIN #{@table_prefix}vote_desc v ON (v.vote_id = r.vote_id)
          JOIN #{@table_prefix}topics t ON (v.topic_id = t.topic_id)
        WHERE t.topic_id = #{topic_id}
      SQL
    end

    def get_max_attachment_size
      query(<<-SQL).first[:filesize]
        SELECT IFNULL(MAX(filesize), 0) AS filesize
        FROM #{@table_prefix}attach_desc
      SQL
    end

    def fetch_attachments(topic_id, post_id)
      query(<<-SQL)
        SELECT ad.physical_filename, ad.real_filename
        FROM #{@table_prefix}attach_desc ad
          JOIN #{@table_prefix}attach a ON (a.attach_id = ad.attach_id)
          JOIN #{@table_prefix}posts p ON (p.post_id = a.post_id)
          JOIN #{@table_prefix}topics t ON (t.topic_id = p.topic_id)
        WHERE t.topic_id = #{topic_id} AND a.post_id = #{post_id}
        ORDER BY ad.upload_time DESC, p.post_id
      SQL
    end

    def count_messages
      count(<<-SQL)
        SELECT COUNT(*) AS count
        FROM #{@table_prefix}privmsgs m
        WHERE NOT EXISTS ( -- ignore duplicate messages
                    SELECT 1
                    FROM #{@table_prefix}privmsgs x
                    WHERE x.privmsgs_id < m.privmsgs_id
                    AND x.privmsgs_subject = m.privmsgs_subject
                    AND x.privmsgs_from_userid = m.privmsgs_from_userid
                    AND x.privmsgs_to_userid = m.privmsgs_to_userid AND x.privmsgs_date = m.privmsgs_date
                  )
      SQL
    end

    def fetch_messages(last_msg_id)
      query(<<-SQL, :privmsgs_id)
        SELECT DISTINCT m.privmsgs_id, m.privmsgs_from_userid, m.privmsgs_date, m.privmsgs_subject,
          pt.privmsgs_text, m.privmsgs_to_userid
        FROM #{@table_prefix}privmsgs m
          JOIN #{@table_prefix}privmsgs_text pt ON (m.privmsgs_id = pt.privmsgs_id)
        WHERE NOT EXISTS ( -- ignore duplicate messages
                    SELECT 1
                    FROM #{@table_prefix}privmsgs x
                    WHERE x.privmsgs_id < m.privmsgs_id
                    AND x.privmsgs_subject = m.privmsgs_subject
                    AND x.privmsgs_from_userid = m.privmsgs_from_userid
                    AND x.privmsgs_to_userid = m.privmsgs_to_userid AND x.privmsgs_date = m.privmsgs_date
                  )
        AND m.privmsgs_id > #{last_msg_id}
        ORDER BY m.privmsgs_id
        LIMIT #{@batch_size}
      SQL
    end

    def count_bookmarks
      count(<<-SQL)
        SELECT COUNT(*) AS count
        FROM #{@table_prefix}bookmarks b
        WHERE b.relation_type = #{Constants::BOOKMARK_TYPE_TOPIC}
      SQL
    end

    # user bookmarks and forum bookmarks are not supported by discourse,
    # we only import topic bookmarks
    def fetch_bookmarks(last_user_id, last_bookmark_id)
      query(<<-SQL, :user_id, :bookmark_id)
        SELECT b.user_id, b.bookmark_id, t.topic_first_post_id AS post_id
        FROM #{@table_prefix}bookmarks b
          JOIN #{@table_prefix}topics t ON (b.relation_id = t.topic_id)
        WHERE b.relation_type = #{Constants::BOOKMARK_TYPE_TOPIC} AND b.user_id > #{last_user_id} AND b.bookmark_id > #{last_bookmark_id}
        ORDER BY user_id, bookmark_id
        LIMIT #{@batch_size}
      SQL
    end

    def count_smilies
      count(<<-SQL)
        SELECT COUNT(*) AS count
        FROM #{@table_prefix}smilies s
      SQL
    end

    def fetch_smilies(last_smilie_id)
      query(<<-SQL, :smilie_id)
        SELECT s.smilie_id, s.code, s.url, s.disk_name
        FROM #{@table_prefix}smilies s
        WHERE s.smilie_id > #{last_smilie_id}
        ORDER BY smilie_id
        LIMIT #{@batch_size}
      SQL
    end
  end
end
