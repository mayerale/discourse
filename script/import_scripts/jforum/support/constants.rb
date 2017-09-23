module ImportScripts::JForum
  class Constants
    ACTIVE_USER = 1
    #INACTIVE_REGISTER = 0 # Newly registered account
    #INACTIVE_PROFILE = 2 # Profile details changed
    #INACTIVE_MANUAL = 3 # Account deactivated by administrator
    #INACTIVE_REMIND = 4 # Forced user account reactivation

    # TODO morn provide settings
    GROUP_ADMINISTRATORS = 'Administration'
    GROUP_MODERATORS = 'Moderatoren'

    # TODO morn check all user types
    USER_TYPE_NORMAL = 0
    USER_TYPE_INACTIVE = 1
    USER_TYPE_IGNORE = 2
    USER_TYPE_FOUNDER = 3

    AVATAR_TYPE_UPLOADED = 0
    AVATAR_TYPE_REMOTE = 1

    TOPIC_NORMAL = 0
    TOPIC_STICKY = 1
    TOPIC_ANNOUNCE = 2

    BOOKMARK_TYPE_FORUM = 1
    BOOKMARK_TYPE_TOPIC = 2
    BOOKMARK_TYPE_USER = 3
  end
end
