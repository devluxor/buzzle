# Custom Sinatra condition that detects the HTTP request method
set(:request_method) do |method|
  method = method.to_s.upcase
  condition { request.request_method == method }
end

# Request-specific validation subroutines:

  ## Each route:
      # Checks if the user is logged in
      # Checks for errors in identifiers provided, if any
      # Checks for errors in user input via forms or query strings, if any

  ## If there is a bad input of any kind, a symbol representing the specific error
  ## will be returned from the block associated to each check_parameter call.
  ## Depending on the type of error, the appropiate HTML/erb content will be assigned to an
  ## instance variable that will be used as the response body in the route (see ../buzzle.rb),
  ## while displaying a flash error message.
  ## If no input errors are found by these subroutines, 
  ## no values will be assigned to the error-capturing instance variables, 
  ## and the main code in the route will be executed.

# Pre-login: 

before '/login', request_method: :post do
  access_control_subroutine
  capture_input_user_data
  @input_errors = check_parameters(:login) { validate_login_credentials(@user_input_data) }
end

before '/new_user', request_method: :post do
  connect_to_db
  capture_input_user_data
  @input_errors = check_parameters(:new_user) { validate_new_user_data(@user_input_data) }
end

# Post-login: 

before '/' do
  access_control_subroutine
  check_pagination('/', :boards)
  load_pagination(:boards)
end

before '/users/:id/profile', request_method: :get do
  access_control_subroutine
  @current_profile_id = params[:id]
  @invalid_user_id = check_parameters('/') { validate_user_identifier(@current_profile_id) }
end

before '/users/:id/profile', request_method: :post do
  access_control_subroutine
  @current_profile_id = params[:id]
  capture_input_user_data
  @invalid_user_id = check_parameters('/') { validate_user_identifier(@current_profile_id) }
  @unauthorized_user = check_parameters("/users/#{@current_profile_id}/profile") do
      validate_user_identifier(@current_profile_id)
    end
  @input_errors = check_parameters("/users/#{@current_profile_id}/profile") do
      validate_update_user_data(@user_input_data)
    end
end

before '/new_board', request_method: :post do
  access_control_subroutine
  capture_input_board_data
  @input_errors = check_parameters('/') { validate_board_data(@board_input_data) }
end

before '/boards/:id', request_method: :get do
  access_control_subroutine
  @id = params[:id]
  @invalid_id = check_parameters('/') { validate_board_identifier(@id) }
  check_pagination("/boards/#{@id}", :board_messages)
  load_pagination(:board_messages)
end

before '/boards/:id', request_method: :post do
  access_control_subroutine
  @id = params[:id]
  @message = remove_extra_newlines(params[:message])
  @invalid_id = check_parameters('/') { validate_board_identifier(@id) }
  @input_errors = check_parameters("/boards/#{@id}") { validate_message(@message) }
end

before '/boards/:id/edit', request_method: :get do
  access_control_subroutine
  @id = params[:id]
  @invalid_id = check_parameters('/') { validate_board_identifier(@id) }
  @unauthorized_user = check_parameters("/boards/#{@id}") { validate_board_rights(@id) }
end

before '/boards/:id/edit', request_method: :post do
  access_control_subroutine
  @id = params[:id]
  capture_input_board_data
  @invalid_id = check_parameters('/') { validate_board_identifier(@id) }
  @unauthorized_user = check_parameters("/boards/#{@id}") { validate_board_rights(@id) }
  @input_errors = check_parameters("/boards/#{@id}/edit") { validate_board_data(@board_input_data) }
end

before '/boards/:board_id/edit/:message_id', request_method: :get do
  access_control_subroutine
  @board_id = params[:board_id]
  @message_id = params[:message_id]
  @invalid_board_id = check_parameters('/') { validate_board_identifier(@board_id) }
  @invalid_message_id = check_parameters("/boards/#{@board_id}") { validate_board_message_id(@board_id, @message_id)}
  @unauthorized_user = check_parameters('/') { validate_board_message_rights(@message_id) }
end

before '/boards/:board_id/edit/:message_id', request_method: :post do
  access_control_subroutine
  @board_id = params[:board_id]
  @message_id = params[:message_id]
  @new_message = remove_extra_newlines(params[:message])
  @invalid_board_id = check_parameters('/') { validate_board_identifier(@board_id) }
  @invalid_message_id = check_parameters("/boards/#{@board_id}") { validate_board_message_id(@board_id, @message_id)}
  @unauthorized_user = check_parameters('/') { validate_board_message_rights(@message_id) }
  @input_errors = check_parameters("/boards/#{@board_id}/edit/#{@message_id}") { validate_message(@new_message) }
end

before '/boards/:board_id/edit/:message_id/delete', request_method: :post do
  access_control_subroutine
  @board_id = params[:board_id]
  @message_id = params[:message_id]
  @invalid_board_id = check_parameters('/') { validate_board_identifier(@board_id) }
  @invalid_message_id = check_parameters("/boards/#{@board_id}") { validate_board_message_id(@board_id, @message_id)}
  @unauthorized_user = check_parameters('/') { validate_board_message_rights(@message_id) }
end

before '/boards/:id/delete', request_method: :post do
  access_control_subroutine
  @id = params[:id]
  @invalid_board_id = check_parameters('/') { validate_board_identifier(@id) }
  @unauthorized_user = check_parameters('/') { validate_board_rights(@id) }
end

before '/send_message', request_method: :post do
  access_control_subroutine
  @receiver_id = params[:receiver_id]
  @message = remove_extra_newlines(params[:message])
  @invalid_user_id = check_parameters('/') { validate_user_identifier(@receiver_id) }
  @input_errors = check_parameters("/users/#{@receiver_id}/profile") { validate_message(@message) }
end

before '/conversations', request_method: :get do
  access_control_subroutine
  check_pagination('/conversations', :conversations)
  load_pagination(:conversations)
end

before '/conversations/:id', request_method: :get do
  access_control_subroutine
  @conversation_id = params[:id]
  
  @input_errors = check_parameters('/conversations') { validate_conversation(@conversation_id) }
  check_pagination('/conversations', :single_conversation)
  load_pagination(:single_conversation)
end

before '/conversations/:id/delete', request_method: :post do
  access_control_subroutine
  @conversation_id = params[:id]
  @input_errors = check_parameters('/conversations') { validate_conversation(@conversation_id) }
end

before '/history', request_method: :get do
  access_control_subroutine
  check_pagination('/history', :history)
  load_pagination(:history)
end

before '/settings', request_method: :get do
  access_control_subroutine
  # In case of redirection, this purges this instance variable from possible previous password inputs:
  # (See ./helpers.rb, #log_in_user, #log_out_user)
  @password_update_input_data = nil
end

before '/settings', request_method: :post do
  access_control_subroutine
  capture_new_password_input
  @input_errors = check_parameters('/settings') { validate_password_update(@password_update_input_data) }
end

before '/search', request_method: :get do
  access_control_subroutine
  @term = session[:search_term_minicache]&.strip&.chomp
  redirect '/' unless @term
  
  @invalid_search_term = check_parameters('/') { validate_search(session[:search_term_minicache]) }
  check_pagination('/', :search_results)
  load_pagination(:search_results)
end

before '/search',  request_method: :post do
  access_control_subroutine
  session[:search_term_minicache] = params[:term].strip
  @term = params[:term].strip
  @invalid_search_term = check_parameters('/') { validate_search(session[:search_term_minicache]) }
  load_pagination(:search_results)
end

before '/logout', request_method: :get do
  access_control_subroutine
end

before '/delete_account', request_method: :post do
  access_control_subroutine
end
