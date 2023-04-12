require 'pg'
require 'bcrypt'
require 'paint'

require_relative 'queries'

MAX_INTEGER ||= 2_147_483_647
MAX_BOARDS_PER_PAGE ||= 6
MAX_MESSAGES_PER_PAGE ||= 3

# Points per action: (see lines 271-273)
BOARD_MESSAGE ||= 1
PRIVATE_MESSAGE ||= 5
NEW_BOARD ||= 10

class DatabaseInteraction 
  def initialize(logger)
    @db = PG.connect(dbname: 'buzzle')
    @logger = logger
  end

  def query(statement, *params)
    color = to_color(statement)
    @logger.info("QUERY:\n#{Paint[statement, color]} #{Paint["\nPARAMS.: #{params}", :magenta]}")
    @db.exec_params(statement, params)
  end

  def disconnect
    @db.close
  end

  def pages_for(content_type, parameter = nil)
    statement = to_statement(content_type)
    parameter = format_search_term(parameter) if content_type == :search_results
    if content_type == :boards
      limit_per_page = MAX_BOARDS_PER_PAGE
      number_of_entities = query(statement).ntuples
    else
      limit_per_page = MAX_MESSAGES_PER_PAGE
      number_of_entities = query(statement, parameter).ntuples
    end

    pages = (number_of_entities / limit_per_page.to_f).ceil
    pages.zero? ? 1 : pages
  end

  # This method deletes boards more than 1 day old if the author's account does not longer exist.
  def purge_old_boards!
    query(PURGE_OLD_BOARDS)
  end

  def messages_unread?(user_id)
    query(MESSAGES_UNREAD, user_id).ntuples.positive?
  end

  def load_users
    query(LOAD_USERS)
  end

  def last_board_messages
    query(LAST_BOARD_MESSAGES)
  end

  def top_users
    query(TOP_USERS)
  end

  def add_new_user!(user_data)
    encrypted_password = BCrypt::Password.create(user_data[:password])
    query(
      ADD_NEW_USER, 
      user_data[:username], 
      user_data[:first_name], 
      user_data[:last_name], 
      encrypted_password, 
      user_data[:about_me], 
      user_data[:portrait]
    )
  end

  def find_user_id(username)
    query(FIND_USER_ID, username).first['id']
  end

  def user_info(identifier, username: false)
    return unless valid_identifier?(identifier)

    statement = username ? USER_INFO_BY_USERNAME : USER_INFO_BY_ID
    query(statement, identifier)&.first
  end

  def add_new_board!(board_data, author_id)
    query(
      ADD_NEW_BOARD, 
      board_data[:title], 
      board_data[:description], 
      author_id,
      board_data[:color]
    )
    add_score!(NEW_BOARD, author_id)
  end

  def board_exists?(id)
    query(FIND_BOARD, id).ntuples == 1
  end

  def load_all_boards(page_number)
    to_array(
      query(ALL_BOARDS, big_offset(page_number))
    )
  end

  def load_board_messages(board_id, page_number)
    to_array(
      query(BOARD_MESSAGES, board_id, small_offset(page_number))
    )
  end

  def board_info(board_id)
    query(BOARD_INFO, board_id).first
  end

  def add_board_message!(message, author_id, board_id)
    query(ADD_MESSAGE, message, author_id, board_id)
    add_score!(BOARD_MESSAGE, author_id)
  end

  def edit_board!(id, board_data)
    query(
      EDIT_BOARD,
      board_data[:title], 
      board_data[:description], 
      board_data[:color],
      id
    )
  end

  def board_message_info(message_id)
    query(FIND_BOARD_MESSAGE, message_id)&.first
  end

  def edit_board_message!(message, message_id)
    query(EDIT_BOARD_MESSAGE, message, message_id)
  end

  def send_private_message!(message, sender_id, receiver_id)
    if first_message?(sender_id, receiver_id)
      create_conversation!(sender_id, receiver_id)
    else
      update_conversation!(sender_id, receiver_id)
    end
    
    query(SEND_PRIVATE_MESSAGE, message, sender_id, receiver_id)
    add_score!(PRIVATE_MESSAGE, sender_id)
  end

  def find_last_private_message(sender_id, receiver_id)
    query(FIND_LAST_PRIVATE_MESSAGE, sender_id, receiver_id).first
  end

  def load_conversations(user_id, page_number)
    query(LOAD_CONVERSATIONS, user_id, small_offset(page_number))
  end

  def load_private_messages(conversation_id, page_number)
    query(LOAD_PRIVATE_MESSAGES, conversation_id, small_offset(page_number))
  end

  def delete_conversation!(conversation_id)
    query(DELETE_CONVERSATION, conversation_id)
  end

  def load_history(user_id, page_number)
    query(LOAD_HISTORY, user_id, small_offset(page_number))
  end

  def delete_board_message!(message_id)
    query(DELETE_BOARD_MESSAGE, message_id)
  end

  def delete_board!(id)
    query(DELETE_BOARD, id)
  end

  def update_profile_data!(user_id, user_data)
    query(
      UPDATE_PROFILE_DATA, 
      user_id,
      user_data[:username], 
      user_data[:first_name], 
      user_data[:last_name], 
      user_data[:about_me],
      user_data[:portrait]
    )
  end

  def update_password!(user_id, new_password)
    encrypted_password = BCrypt::Password.create(new_password)
    query(UPDATE_PASSWORD, user_id, encrypted_password)
  end

  def delete_user!(id)
    query(DELETE_USER, id)
  end

  def set_messages_read!(user_id, conversation_id)
    query(SET_MESSAGES_READ, user_id, conversation_id)
  end

  def search_board_messages(term, page_number)
    query(
      SEARCH_MESSAGES, 
      format_search_term(term),
      small_offset(page_number)
    )
  end

  def valid_new_username?(user_id, new_username)
    query(VALID_NEW_USERNAME, user_id, new_username).ntuples.zero?
  end

  def conversation_info(id)
    query(CONVERSATION_INFO, id)&.first
  end

  private

  def to_color(statement)
    case query_type(statement)
    when 'SELECT'
      :green
    when 'UPDATE'
      :yellow
    when 'INSERT'
      :blue
    else 
      :red
    end
  end

  def query_type(statement)
    statement[0...statement.index(' ')]
  end

  def to_statement(content_type)
    case content_type
    when :boards
      COUNT_BOARDS
    when :board_messages
      COUNT_BOARD_MESSAGES
    when :conversations
      COUNT_CONVERSATIONS
    when :single_conversation
      COUNT_CONVERSATION_MESSAGES
    when :history
      COUNT_HISTORY
    when :search_results
      COUNT_SEARCH_RESULTS
    end
  end

  def first_message?(user_a_id, user_b_id)
    query(CONVERSATION_EXISTS, user_a_id, user_b_id).ntuples.zero?
  end

  def create_conversation!(user_a_id, user_b_id)
    query(CREATE_CONVERSATION, user_a_id, user_b_id)
  end

  def update_conversation!(user_a_id, user_b_id)
    query(UPDATE_CONVERSATION, user_a_id, user_b_id)
  end

  def add_score!(points, user_id)
    query(ADD_SCORE, points, user_id)
  end

  def valid_identifier?(identifier)
    (0...MAX_INTEGER).cover? identifier.to_i
  end

  def to_array(query_result)
    query_result.map { |tuple| tuple }
  end

  def format_search_term(term)
    "%#{term}%"
  end

  def big_offset(page_number)
    (page_number.to_i - 1) * MAX_BOARDS_PER_PAGE
  end

  def small_offset(page_number)
    (page_number.to_i - 1) * MAX_MESSAGES_PER_PAGE
  end
end
