require 'sinatra'
require 'sinatra/content_for'
require 'tilt/erubis'

require_relative 'db/database_interaction'
require_relative 'lib/helpers'
require_relative 'lib/user_input_validation'
require_relative 'lib/validation_subroutines'

# Status codes and configuration:

BAD_REQUEST = 400
UNAUTHORIZED = 401
NOT_FOUND = 404
UNPROCESSABLE_CONTENT = 422

SESSION_SECRET = '89ff09c339ac1df5cb1f9e1959ef913f1828c1048f777ef05f0aec54de0f1453'.freeze

configure do
  set :erb, escape_html: true
  enable :sessions
  set :session_secret, SESSION_SECRET
end

after do
  @storage&.disconnect
end

# Routes:
# (See ./lib/validation_subroutines.rb, ./lib/user_input_validation.rb
#  to see request-specific control access and validation subroutines)

get '/' do
  @invalid_page || (
    @boards = @storage.load_all_boards(@current_page)
    erb :main
  )
end

get '/login' do
  status UNAUTHORIZED if session.delete(:unauthorized_access)
  erb :login, layout: :pre_access
end

post '/login' do
  @input_errors || (
    @storage.purge_old_boards!
    flash_message(:valid_login)
    log_in_user
  )
end

get '/new_user' do
  erb :new_user, layout: :pre_access
end

post '/new_user' do
  @input_errors || (
    @storage.add_new_user!(@user_input_data)
    flash_message(:valid_new_user)
    log_in_user
  )
end

post '/new_board' do
  @input_errors || (
    @storage.add_new_board!(@board_input_data, session[:user_id])
    flash_message(:valid_board)
    redirect '/'
  )
end

get '/boards/:id' do
  @invalid_id || 
    @invalid_page || (
      @messages = @storage.load_board_messages(@id, @current_page)
      load_board_data_from(@messages)
      erb :board
    )
end

post '/boards/:id' do
  @invalid_id || 
    @input_errors || (
      @storage.add_board_message!(@message, session[:user_id], @id)
      redirect "/boards/#{@id}"
    )
end

get '/boards/:id/edit' do
  @invalid_id || (
    @unauthorized_user ||
      @board_info = @storage.board_info(@id)
      erb :edit_board
    )
end

post '/boards/:id/edit' do
  @invalid_id ||
    @unauthorized_user || 
      @input_errors || (
        @storage.edit_board!(@id, @board_input_data)
        flash_message(:valid_board_edit)
        redirect '/'
      )
end

get '/boards/:board_id/edit/:message_id' do
  @invalid_board_id ||
    @invalid_message_id ||
      @unauthorized_user || (
        @message = @storage.board_message_info(@message_id)['content']
        erb :edit_board_message
      )
end

post '/boards/:board_id/edit/:message_id' do
  @invalid_board_id ||
    @invalid_message_id ||
      @unauthorized_user ||
        @input_errors || (
          @storage.edit_board_message!(@new_message, @message_id)
          redirect "/boards/#{@board_id}"
        )
end

post '/boards/:board_id/edit/:message_id/delete' do
  @invalid_board_id ||
    @invalid_message_id ||
      @unauthorized_user || (
          @storage.delete_board_message!(@message_id)
          redirect "/boards/#{@board_id}"
        )
end

post '/boards/:id/delete' do
  @invalid_board_id || 
    @unauthorized_user || (
      @storage.delete_board!(@id)
      flash_message(:valid_delete_board)
      redirect '/'
    )
end

get '/users/:id/profile' do
  @invalid_user_id || (
    @user_info = @storage.user_info(@current_profile_id)
    erb :profile
  )
end

post '/users/:id/profile' do
  @invalid_user_id || 
    @unauthorized_user ||
      @input_errors || (
        @storage.update_profile_data!(session[:user_id], @user_input_data)
        flash_message(:valid_update_user)
        update_session_user_data
        redirect "users/#{session[:user_id]}/profile"
      )
end

post '/send_message' do
  @invalid_user_id ||
    @input_errors || (
      @storage.send_private_message!(@message, session[:user_id], @receiver_id)
      conversation_id = @storage.find_last_private_message(session[:user_id], @receiver_id)['conversation_id']
      flash_message(:valid_message)
      redirect "conversations/#{conversation_id}"
    )
end

get '/conversations' do
  @invalid_page || (
    @conversations = @storage.load_conversations(session[:user_id], @current_page)
    erb :conversations
  )
end

get '/conversations/:id' do
  @input_errors ||
    @invalid_page || (
      @storage.set_messages_read!(session[:user_id], @conversation_id)
      @messages = @storage.load_private_messages(@conversation_id, @current_page)
      erb :single_conversation
    )
end

post '/conversations/:id/delete' do
  @input_errors || (
    @storage.delete_conversation!(@conversation_id)
    flash_message(:valid_delete_conversation)
    redirect '/conversations'
  )
end

get '/history' do
  @invalid_page || (
    @messages = @storage.load_history(session[:user_id], @current_page)
    erb :history
  )
end

get '/settings' do
  @user_info = @storage.user_info(session[:user_id])
  erb :settings
end

post '/settings' do
  @input_errors || (
    @storage.update_password!(session[:user_id], @password_update_input_data[:new_password])
    @password_update_input_data = nil
    flash_message(:valid_update_password)
    redirect '/settings'
  )
end

get '/search' do
  @invalid_search_term || (
    @messages = @storage.search_board_messages(session[:search_term_minicache], @current_page)
    erb :search_results
  )
end

post '/search' do
  @invalid_search_term || (
    @messages = @storage.search_board_messages(@term, @current_page)
    erb :search_results
  )
end

post '/delete_account' do
  @storage.delete_user!(session[:user_id])
  log_out_user
  flash_message(:valid_delete_user)
  redirect '/login'
end

get '/logout' do
  log_out_user
  flash_message(:valid_logout)
  redirect '/login'
end

not_found do
  erb :not_found, layout: :pre_access
end

