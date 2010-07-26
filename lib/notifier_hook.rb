require 'tinder'

class NotifierHook < Redmine::Hook::Listener
  @@subdomain = nil
  @@token     = nil
  @@room      = nil
  @@projects  = []

  def self.load_options
    options     = YAML::load( File.open(File.join(File.dirname(__FILE__), '..', 'config', 'campfire.yml')) )
    @@subdomain = options[Rails.env]['subdomain']
    @@token     = options[Rails.env]['token']
    @@room      = options[Rails.env]['room']
    @@projects  = options[Rails.env]['projects'].split(/\s*,\s*/)
    RAILS_DEFAULT_LOGGER.warn(options.inspect)
  end

  def controller_issues_new_after_save(context = { })
    @issue = context[:issue]
    @user = @issue.author
    speak "#{@user.firstname} created issue “#{@issue.subject}”. Comment: “#{truncate_words(@issue.description)}” http://#{Setting.host_name}/issues/#{@issue.id}", @issue.project
  end
  
  def controller_issues_edit_after_save(context = { })
    @issue = context[:issue]
    @journal = context[:journal]
    @user = @journal.user
    speak "#{@user.firstname} edited issue “#{@issue.subject}”. Comment: “#{truncate_words(@journal.notes)}”. http://#{Setting.host_name}/issues/#{@issue.id}", @issue.project
  end

  def controller_messages_new_after_save(context = { })
    @message = context[:message]
    @user = @message.author
    speak "#{@user.firstname} wrote a new message “#{@message.subject}” on #{@project.name}: “#{truncate_words(@message.content)}”. http://#{Setting.host_name}/boards/#{@message.board.id}/topics/#{@message.root.id}#message-#{@message.id}", @message.board.project
  end
  
  def controller_messages_reply_after_save(context = { })
    @message = context[:message]
    @user = @message.author
    speak "#{@user.firstname} replied a message “#{@message.subject}” on #{@project.name}: “#{truncate_words(@message.content)}”. http://#{Setting.host_name}/boards/#{@message.board.id}/topics/#{@message.root.id}#message-#{@message.id}", @message.board.project
  end
  
  def controller_wiki_edit_after_save(context = { })
    @project = context[:project]
    @page = context[:page]
    @user = @page.content.author
    speak "#{@user.firstname} edited the wiki “#{@page.pretty_title}” on #{@project.name}. http://#{Setting.host_name}/projects/#{@project.identifier}/wiki/#{@page.title}", @project
  end

private
  def speak(message,project=nil)
    NotifierHook.load_options unless @@subdomain && @@token && @@room
    RAILS_DEFAULT_LOGGER.error "Projects: #{@@projects.inspect}"
    RAILS_DEFAULT_LOGGER.error "#{project}: #{message}"
    return true unless @@projects.include? project.identifier
    begin
      campfire = Tinder::Campfire.new @@subdomain, :token => @@token
      room = campfire.find_room_by_name(@@room)
      room.speak message
    rescue => e
      logger.error "Error during campfire notification: #{e.message}"
    end
  end

  def truncate_words(text, length = 20, end_string = '…')
    return if text == nil
    words = text.split()
    words[0..(length-1)].join(' ') + (words.length > length ? end_string : '')
  end
end
