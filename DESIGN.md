## An overview of the overall functioning of the application

A Sinatra application is basically a collection of 'routes' or URL _patterns_ of HTTP requests sent from the client to the server, and the definition of the corresponding HTTP response to those requests; in other words, for every request with a path defined in a route or _pattern_, there is a response, defined inside each route block.
For example, if we want the user to see the login page, we define a route with the HTTP method used to send that request to the server, `GET`. Then, we add a pattern with the desired URL path, `/login`, and we define a block that will contain the behavior that will follow the server after a request with these characteristics. The return value of the block will determine, at least, the response body passed on to the HTTP client. In Buzzle, most of the time this will be a string containing HTML code defined in a `.erb` template, loaded by an `erb` method.

```ruby
get '/login' do
  erb :login, layout: :pre_access
end
```

However, the login page will contain a form to send the user's credentials via a `POST` request; we need to define a route for this request too:

```ruby
post '/login' do
  @storage.check_credentials(username, password) 
  # @storage is assigned to a DatabaseInteraction object, used by the app to 'talk' with the database.
  flash_message(:valid_login)
  log_in_user
end
```

First, we indicate the user that the validation was successful, and then we log in the user via a `log_in_user` helper.

```ruby
# This is a very simplified version of the method.
def log_in_user
  session[:logged_in] = true
  redirect '/main_page'
end
```

The redirection will trigger another defined route, that could be illustrated by this:

```ruby
get '/main_page' do
  erb :main_page # This method will load the main page HTML template as the HTTP response body.
end
```
However, many things can go wrong. What happens if the password introduced is not correct, or, even worse, contains a script injection attack? We could define the `post` route like this instead:

```ruby
post '/login' do
  validation_result = @storage.check_credentials(username, password) 
  if validation_result == :incorrect_password
    flash_message(:incorrect_password)
    redirect '/login'
  elsif validation_result == :danger_script_attack
    flash_message(:danger_script_attack)
    redirect '/login'
  else
    flash_message(:valid_login)
    log_in_user
  end
end
```

This solution may work as what we want initially, but imagine how messy `buzzle.rb` can become, with dozens of routes, and, inside every route, the same validation processes and methods again and again, with all the different possible input errors. This would make the program difficult to read, and somehow less elegant and inefficient. 

Let's make a visit to the `validation_subroutines.rb` file. In this file, there is a _filter_ for each route, a series of subroutines that will make sure there are no errors in the data input by the user, while informing him or her of what went wrong. Consider this example:

```ruby
before '/login', request_method: :post do
  access_control_subroutine
  capture_input_user_data
  @input_errors = check_parameters(:login) { validate_login_credentials(@user_input_data) }
end
```

Each time a `POST` request with a path of `/login` is sent to the server, this code is executed, before the route defined in the main app file `buzzle.rb` is triggered: 

1. `access_control_subroutines` makes sure the connection with the database is initialized by assigning a `DatabaseInteraction` object to the `@storage` instance variable; 
2. `capture_input_user_data` captures all the values sent via the HTML form in a single hash to which the `@user_input_data` variable is assigned to. 
3. If there is a bad input of any kind, a symbol representing the specific error (incorrect password, forbidden symbols, etc.) will be returned from the block associated to the `check_parameter` method. Depending on the type of error, the appropiate HTML/erb content will be assigned to an instance variable that will be used as the response body in the route defined in the main app file `buzzle.rb`, while displaying a flash error message. If no input errors are found by `check_parameter`, no values will be assigned to the error-capturing instance variable, `@input_error`. The main advantage of defining a custom `check_parameter` method is that, analyzing the return value of the code block provided, we can use it to validate any input in any other filter, just adapting what method we invoke inside each block. For example, this is the filter for the `/new_user` `POST` request:

```ruby
before '/new_user', request_method: :post do
  connect_to_db
  capture_input_user_data
  @input_errors = check_parameters(:new_user) { validate_new_user_data(@user_input_data) }
end
```

Having this top-level, universally available `@input_errors` variable, we can make use of it in an elegant, almost DSL-ish way in the `/login` route:

```ruby
post '/login' do
  @input_errors || (
    @storage.purge_old_boards!
    flash_message(:valid_login)
    log_in_user
  )
end
```

If `@input_errors` is assigned to a value (not `nil`) within the `before` filter, it will become the route's return value, via the `||` logical operator, and thus the body of the following HTTP request; but, if no errors were found (`@input_errors` having a `nil` value), then the main code of the route will be executed. To illustrate this approach even more, here it is another example of the filter for the `POST` HTTP request to send new values when editing a board, and the corresponding route:

```ruby
# This is executed before the route:
before '/boards/:id/edit', request_method: :post do
  access_control_subroutine
  @id = params[:id]
  capture_input_board_data
  @invalid_board_id = check_parameters('/') { validate_board_identifier(@id) }
  @unauthorized_user = check_parameters('/') { validate_board_rights(@id) }
  @input_errors = check_parameters('/') { validate_board_data(@board_input_data) }
end
```

```ruby
# And this is the route:
post '/boards/:id/edit' do
  @invalid_board_id ||
    @unauthorized_user || 
      @input_errors || (
        @storage.edit_board!(@id, @board_input_data)
        flash_message(:valid_board_edit)
        redirect '/'
      )
end
```
Expressed in plain words, this cascade-like structure in the route means: if no errors were found in the board identifier, nor the user was not authorized to edit this board, nor there were errors in the new board values, the main route code can be executed. This approach makes, in my opinion, the routes much cleaner and easy to follow along, while keeping a valuable flexibility and the separation of concerns between the different validation subroutines, and the main, expected code to run within each route.

## Application organization and structure

Pseudo-modular structure (Sinatra)


## The database

The database is composed by five tables representing five types of entities: _users_, _boards_, _board messages_, _private messages_ and _conversations_. A user is represented by a row in the `users` table that contains all the account information; a row in the `boards` table represents a message board posted by a single user, and has all the information about that board, like when it was posted, its title and description, its color, etc.; `board_messages` contains every single message posted in any board, with all the appropriate information; one row in `private_messages` represents each message sent by a user to another user, along all its information too. The `conversations` table, on the other hand, represents _a single channel of communication between two users_, or a private conversation between a user 'a' and a user 'b'; the table contains a primary key for the conversation, identifiers for both users, and the timestamp of the last message sent by 'a' to 'b' or vice versa. Of course, every time a private message is sent, the program checks if there's already a conversation going on between sender and receiver: if there is, it updates the timestamp in the corresponding `conversations` row, and sends the message; if there is not, it creates a new conversation.

Relationships between entities:

| **Entity A**  | **Entity B**        | **Type of Relationship** |
|--------------|-----------------|----------------------|
| User         | Board           | 1:M                  |
| Board        | Board Message   | 1:M                  |
| User         | Private Message | 1:M                  |
| Conversation | User            | M:M                  |

Probably, the most arguable point in this approach is the inclusion of a `conversations` table. Why not just grouping the private messages by user 'a' and user 'b' to load all the ongoing conversations between the current user and others? We could 

## Other design choices



