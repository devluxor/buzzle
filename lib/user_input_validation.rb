require 'bcrypt'

ONLY_NUMBERS ||= %r{\A\d+\z}
FORBIDDEN_CREDENTIAL_CHARACTERS ||= %r{[^\w]}
FORBIDDEN_NAME_CHARACTERS ||= %r{[^\w\-' ]}
FORBIDDEN_ABOUT_ME_CHARACTERS ||= %r{[^\w\s\-!?'\;\.\,\+\=\(\)\#\%\"]}
FORBIDDEN_MESSAGE_CHARACTERS ||= %r{[^\w\s\-!?'\;\.\,\+\=\(\)\#\%\\\/\"]}
SEARCH_TERM ||= %r{\A[\w\s\-!?'\.\,\+\#\@\(\)\[\]\{\}]{1,100}\z}

MAX_CREDENTIAL_SIZE ||= 30
MAX_NAME_SIZE ||= 40
MAX_ABOUT_ME_SIZE ||= 250
MAX_BOARD_TITLE ||= 100
MAX_BOARD_DESCRIPTION ||= 100
MAX_MESSAGE ||= 1000
MIN_GENERAL_STRING ||= 3
MIN_MESSAGE ||= 1

MAX_SQL_INTEGER ||= 2_147_483_647

# This method handles errors in validation; reloads/redirects in case any
# input error is found, informing the user via a flash message, returns `nil` if no errors found
def check_parameters(error_response)
  validation_result = yield
  flash_message(validation_result)
  return if valid?(validation_result)

  status define_status_code(error_response)
  layout = error_response.to_s.match?(/login|new_user/) ? :pre_access : :layout
  error_response.is_a?(Symbol) ? erb(error_response, layout: layout) : redirect(error_response)
end

def valid?(validation_message)
  validation_message.match?(%r{\Avalid})
end

def define_status_code(response)
  response.to_s.match?(%r{invalid|incorrect|taken}) ? UNPROCESSABLE_CONTENT : BAD_REQUEST
end

# Input validation --------------------------------------------------------------------------------

def find_errors(*list_of_checks)
  checks_results = list_of_checks.each_with_object([]) { |check, results| results << check }
  
  (checks_results.find { |error| error }) ? checks_results.compact[0].to_sym : :valid
end

def validate_new_user_data(data)
  find_errors(
    check_credential(data, :username, new_user: true),
    check_credential(data, :password, new_user: true),
    check_name(data, :first_name),
    check_name(data, :last_name),
    check_about_me(data),
    check_portrait(data)
  )
end

# Validates username and password
def check_credential(data, type = :username, new_user: false, update: false)
  credential = data[type]
  error_found = 
    if credential.nil?
      "invalid_#{type}"
    elsif credential.match? FORBIDDEN_CREDENTIAL_CHARACTERS
      "forbidden_#{type}"
    elsif credential.empty?
      "empty_#{type}"
    elsif credential.size > MAX_CREDENTIAL_SIZE
      "long_#{type}"
    elsif credential.size < MIN_GENERAL_STRING
      "short_#{type}"
    elsif new_user && type == :password && credential != data[:password_confirmation]
      :unmatched_passwords
    elsif (new_user && type == :username && user_exists?(credential, username: true)) || 
            (update && !valid_new_username?(credential))
      :taken_username
    elsif !update && !new_user && type == :username && !user_exists?(credential, username: true)
      :inexistent_user
    end

  @user_input_data.delete(type) if error_found
  error_found
end

# Validates first and last names
def check_name(data, type = :first_name)
  name = data[type]
  error_found =
    if (name.nil? && type != :last_name) || (name && type != :last_name && name.empty?)
      "invalid_#{type}"
    elsif name && name.match?(FORBIDDEN_NAME_CHARACTERS)
      "forbidden_#{type}"
    elsif name && name.size > MAX_NAME_SIZE
      "long_#{type}"
    elsif name && name.size < MIN_MESSAGE
      "short_#{type}"
    end
  
  @user_input_data.delete(type) if error_found
  error_found
end

def check_about_me(data)
  about_me = data[:about_me]
  return if about_me.nil?
  error_found = 
    if about_me.match? FORBIDDEN_ABOUT_ME_CHARACTERS
      :forbidden_about_me
    elsif about_me.size > MAX_ABOUT_ME_SIZE
      :long_about_me
    elsif about_me.size < MIN_MESSAGE
      :short_about_me
    end

  @user_input_data.delete(:about_me) if error_found
  error_found
end

def check_portrait(data)
  return :invalid_portrait unless load_portraits.include?(data[:portrait])
end


def validate_login_credentials(data)
  find_errors(
    check_credential(data, :username),
    check_credential(data, :password),
    correct_password?(data) ? nil : :incorrect_password
  )
end

def validate_board_data(data)
  find_errors(
    check_board_info(data, type: :title),
    check_board_info(data, type: :description),
    check_board_color(data)
  )
end

def validate_update_user_data(data)
  find_errors(
    check_credential(data, :username, update: true),
    check_name(data, :first_name),
    check_name(data, :last_name),
    check_about_me(data),
    check_portrait(data)
  )
end

def validate_message(text)
  find_errors(
    check_text(text)
  )
end

def check_text(text)
  if text.nil?
    :invalid_message
  elsif text.size > MAX_MESSAGE
    :long_message
  elsif text.match?(FORBIDDEN_MESSAGE_CHARACTERS)
    :forbidden_message
  elsif text.empty?
    :empty_message
  end
end

def validate_password_update(data)
  find_errors(
    check_password_update(data)
  )
end

def check_password_update(data)
  old_password = data[:old_password]
  new_password = data[:new_password]
  new_password_confirmation = data[:new_password_confirmation]

  if [old_password, new_password, new_password_confirmation].any? { |input| input.nil? }
    :invalid_password_input
  elsif !correct_password?(session, old_password)
    :incorrect_old_password
  elsif new_password.match? FORBIDDEN_CREDENTIAL_CHARACTERS
    :forbidden_new_password
  elsif new_password.empty?
    :empty_new_password
  elsif new_password.size > MAX_CREDENTIAL_SIZE
    :long_new_password
  elsif new_password.size < MIN_GENERAL_STRING
    :short_new_password
  elsif new_password != new_password_confirmation
    :unmatched_passwords
  end
end

def validate_conversation(conversation_id)
  find_errors(
    valid_numeric_identifier?(conversation_id) ? nil : :invalid_conversation_identifier,
    check_user_authorization(conversation_id)
  )
end

def valid_numeric_identifier?(id)
  id.match?(ONLY_NUMBERS) && 
    id.to_i.positive? && 
      (id.to_i < MAX_SQL_INTEGER)
end

def check_user_authorization(id)
  return :invalid_conversation_identifier unless valid_numeric_identifier?(id)

  conversation = @storage.conversation_info(id)
  current_user = session[:user_id]
  if conversation.nil? 
    :inexistent_conversation
  elsif (conversation['user_a_id'] != current_user) && (conversation['user_b_id'] != current_user)
    :unauthorized_user
  end
end

def validate_user_identifier(id)
  find_errors(
    valid_numeric_identifier?(id) ? nil : :invalid_user_identifer,
    user_exists?(id) ? nil : :inexistent_user
  )
end

def validate_search(term)
  term.match?(SEARCH_TERM) ? :valid : :invalid_search_term
end

def validate_private_message(data)
  find_errors(
    check_message(data)
  )
end

def validate_page_number(page_number, content_type)
  valid_page_number?(page_number, content_type) ? :valid : :invalid_page_number
end

def validate_board_identifier(id)
  find_errors(
    valid_numeric_identifier?(id) ? nil : :invalid_board_identifier,
    board_exists?(id) ? nil : :inexistent_board
  )
end

def board_exists?(board_id)
  valid_numeric_identifier?(board_id) && @storage.board_exists?(board_id)
end

def validate_board_rights(board_id)
  (@storage.board_info(board_id)&.[]('author_id') == session[:user_id]) ? :valid : :unauthorized_user
end

def validate_board_message_rights(message_id)
  (@storage.board_message_info(message_id)&.[]('author_id') == session[:user_id]) ? :valid : :unauthorized_user
end

def validate_user_profile_rights(id)
  current_user?(id) ? :valid : :invalid_user
end

def valid_new_username?(username)
  @storage.valid_new_username?(session[:user_id], username)
end

def valid_page_number?(page_number, content_type)
  valid_numeric_identifier?(page_number) &&
    !more_than_necessary?(page_number.to_i, content_type)
end

# See ./helpers.rb, #helpers
def more_than_necessary?(page_number, content_type)
  page_number > calculate_pages_needed(content_type)
end

def correct_password?(data, old_password_to_update = nil)
  password_input = old_password_to_update ? old_password_to_update : data[:password]
  user_info = @storage.user_info(data[:username], username: true) || return

  BCrypt::Password.new(user_info&.[]('password')) == password_input
end

def check_board_info(data, type: :title)
  info = data[type]
  
  error_found = 
    if (type == :title && info.nil?) || (type == :title && info.empty?)
      :invalid_title
    elsif type == :title && info.match?(%r{\A[^\w\s\-!?'\.\,]\z})
      "forbidden_#{type}"
    elsif type == :title && info.size > MAX_BOARD_TITLE
      :long_title
    elsif type == :title && info.size < MIN_GENERAL_STRING
      :short_title
    elsif info && type != :title && info.size > MAX_BOARD_DESCRIPTION
      :long_description
    elsif info && type != :title && info.size < MIN_GENERAL_STRING
      :short_description
    end
  
  @board_input_data.delete(type) if error_found
  error_found
end

def check_board_color(data)
  return :invalid_portrait unless BOARD_COLORS.include?(data[:color])
end

def user_exists?(identifier, username: false)
  @storage.user_info(identifier, username: username)
end

def check_pagination(error_response, content_type)
  @invalid_page = check_parameters(error_response) { validate_page_number(params[:page] || '1', content_type) }
end

def validate_board_message_id(board_id, message_id)
  find_errors(
    valid_board_message_id?(board_id, message_id) ? nil : :invalid_board_message_identifier
  )
end

def valid_board_message_id?(board_id, message_id)
  valid_numeric_identifier?(message_id) &&
    @storage.board_message_info(message_id)&.[]('board_id') == board_id
end

