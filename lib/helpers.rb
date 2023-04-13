require 'time'

UNRESTRICTED_URLS = /login|new_user/
PORTRAITS_PATH = './public/images/profile/*.png'.freeze
BOARD_COLORS = %w[orange red blue green black yellow purple].freeze
# error messages in #to_error_message, lines 107-130.
SUCCESS_MESSAGES = {
  login: 'Welcome again!',
  logout: 'Good-bye!',
  new_user: 'Welcome!',
  board: 'Board created successfully!',
  board_edit: 'Board edited successfully!',
  message: 'Message sent successfully!',
  delete_board: 'The board was deleted successfully!',
  delete_conversation: 'The conversation was deleted successfully!',
  update_password: 'You have changed the password successfully!',
  update_user: 'Your data has been updated successfully!',
  delete_user: 'Your account was deleted successfully'
}.freeze
MAX_TITLE_SIZE_LAST_MESSAGES = 40
MAX_CARD_LAST_MESSAGE_SIZE = 100

helpers do
  def access_control_subroutine
    connect_to_db
    require_logged_in_user if restricted_access_requested?
  end

  def connect_to_db
    @storage = DatabaseInteraction.new(logger)
  end

  def restricted_access_requested?
    !request.path.match?(UNRESTRICTED_URLS)
  end

  def require_logged_in_user
    return if user_logged_in?

    session[:unauthorized_access] = true
    session[:last_requested] = request.path
    flash_message(:need_login) unless request.path.match?(%r{\A/\z|/login})
    redirect '/login'
  end

  def user_logged_in?
    session[:logged_in]
  end

  def log_in_user
    user_info = @storage.user_info(@user_input_data[:username], username: true)
    @user_input_data = nil
    @password_update_input_data = nil

    session[:logged_in] = true
    session[:portrait] = user_info['portrait']
    session[:user_id] = user_info['id']
    session[:username] = user_info['username']
    session[:first_name] = user_info['first_name']
    session[:last_name] = user_info['last_name']
    session[:points] = user_info['points']

    redirect session.delete :last_requested
  end

  def update_session_user_data
    session[:username] = @user_input_data[:username]
    session[:portrait] = @user_input_data[:portrait]
    session[:first_name] = @user_input_data[:first_name]
    session[:last_name] =  @user_input_data[:last_name]
    @user_input_data = nil
  end

  def log_out_user
    session.delete :logged_in
    session.delete :portrait
    session.delete :user_id
    session.delete :username
    session.delete :first_name
    session.delete :last_name
    session.delete :points
    session.delete :search_term_minicache
    @user_input_data = nil
    @password_update_input_data = nil
  end

  # refactor:
  def flash_message(validation_result)
    message = validation_result.to_s
    return if message == 'valid'

    message_type = message.match?(/\Avalid_\w+/) ? :success : :error
    session[message_type] = to_flash_message(message)
  end

  def to_flash_message(message)
    validation = message[0...message.index('_')]
    input_element = message[message.index('_') + 1..]

    if validation == 'valid'
      to_success_message(input_element.to_sym)
    else
      to_error_message(validation, input_element.gsub('_', ' '))
    end
  end

  def to_error_message(validation, input_element)
    case validation
    when 'invalid'
      "Please, enter a valid #{input_element}"
    when 'forbidden'
      "The #{input_element} entered contains forbidden characters"
    when /long|short/
      "The #{input_element} entered is too #{validation}"
    when 'unmatched'
      "The passwords entered don't match"
    when 'taken'
      'Sorry, the username entered is already taken'
    when 'incorrect'
      'The password entered is not correct'
    when 'empty'
      "Please, enter #{input_element}"
    when 'inexistent'
      "The #{input_element} entered does not exist"
    when 'unauthorized'
      'You are not authorized to do that'
    when 'need'
      'You need to log in!'
    end
  end

  def to_success_message(input_element)
    SUCCESS_MESSAGES[input_element]
  end

  def load_portraits
    Dir[PORTRAITS_PATH].map { |file| File.basename(file) }
  end

  def capture_input_user_data
    @user_input_data = {
      username: clean(params[:username]),
      password: clean(params[:password]),
      password_confirmation: clean(params[:password_confirmation]),
      portrait: clean(params[:portrait]),
      first_name: clean(params[:first_name]),
      last_name: clean(params[:last_name]),
      about_me: clean(params[:about_me]&.gsub(/\n|\r/, ' '))
    }
  end

  def clean(string)
    string.nil? || string.empty? ? nil : remove_extra_newlines(string.squeeze(' ').strip.chomp)
  end

  def remove_extra_newlines(text)
    text.gsub("\r\n", "\n").squeeze("\n")
  end

  def capture_input_board_data
    @board_input_data = {
      title: clean(params[:title]),
      description: clean(params[:description]),
      color: clean(params[:color])
    }
  end

  def capture_new_password_input
    @password_update_input_data = {
      old_password: params[:old_password],
      new_password: params[:new_password],
      new_password_confirmation: params[:new_password_confirmation]
    }
  end

  def messages_unread?
    @storage.messages_unread?(session[:user_id])
  end

  def load_users
    @storage.load_users
  end

  def last_board_messages
    @storage.last_board_messages
  end

  def top_users
    @storage.top_users
  end

  def format_username(name)
    name.nil? ? 'unknown user' : "@#{name.downcase}"
  end

  def current_user?(user_id)
    user_id == session[:user_id]
  end

  def highlight(text, term)
    text.gsub(/#{term}/i) { |match| "<em>#{match}</em>" }
  end

  def format_time(timestamp)
    time_units = to_time_units(Time.now - Time.parse(timestamp))
    unit, amount = time_units.find { |_unit, amount| amount >= 1 }
    unit = unit.to_s[0..-2] if amount < 2

    "#{amount.floor} #{unit} ago"
  end

  def to_time_units(seconds)
    {
      years: (seconds / '3.154e+7'.to_f).round,
      months: (seconds / '2.628e+6'.to_f).round,
      weeks: (seconds / 604_800).round,
      days: (seconds / 86_400).round,
      hours: (seconds / 3600).round,
      minutes: (seconds / 60).round,
      seconds: seconds.ceil
    }
  end

  def load_pagination(content_type)
    @necessary_pages = calculate_pages_needed(content_type)
    first_page = content_type == :board_messages ? @necessary_pages : 1
    @current_page = params[:page]&.to_i || first_page
  end

  def calculate_pages_needed(content_type)
    @storage.pages_for(content_type, to_parameter(content_type))
  end

  def to_parameter(content_type)
    case content_type
    when :board_messages
      params[:id]
    when :conversations
      session[:user_id]
    when :single_conversation
      @conversation_id
    when :history
      session[:user_id]
    when :search_results
      session[:search_term_minicache]
    end
  end

  def load_board_data_from(messages_data)
    @board_author_id = messages_data.first['board_author_id']
    @title = messages_data.first['board_title']
    @description = messages_data.first['board_description']
  end

  def format_board_title(title)
    if title.size < MAX_TITLE_SIZE_LAST_MESSAGES
      title
    else
      title[0..MAX_TITLE_SIZE_LAST_MESSAGES]
    end
  end

  def format_short_message(message)
    if message.size < MAX_TITLE_SIZE_LAST_MESSAGES
      "'#{message}'"
    else
      "'#{message.strip[0..MAX_TITLE_SIZE_LAST_MESSAGES]}...'"
    end
  end

  def format_last_message(message)
    if message.size < MAX_CARD_LAST_MESSAGE_SIZE
      "'#{message}'"
    else
      "'#{message.strip[0..MAX_CARD_LAST_MESSAGE_SIZE]}...'"
    end
  end

  def format_text(text)
    text.gsub("\n", '<br>')
  end
end
