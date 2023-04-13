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

This solution may work as what we want initially, but imagine how messy `buzzle.rb` can become, with dozens of routes, and, inside route, the same validation processes and methods again and again. This would make the program difficult to read, and somewhat inelegant and inefficient. Let's make a visit to the `validation_subroutines.rb` file. In this file, there is a _filter_ for each route, a series of subroutines that will make sure there are no errors in the data input by the user, while informing him or her of what went wrong. Consider this example:

```ruby
before '/login', request_method: :post do
  access_control_subroutine
  capture_input_user_data
  @input_errors = check_parameters(:login) { validate_login_credentials(@user_input_data) }
end
```

Each time a `POST` request with a path of `/login` is sent to the server, this code is executed: `access_control_subroutines` makes sure the connection with the database is initialized by assigning a `DatabaseInteraction` object to the `@storage` instance variable; `capture_input_user_data` captures all the values sent via the HTML form in a single hash to which the `@user_input_data` variable is assigned to.
If there is a bad input of any kind, a symbol representing the specific error (incorrect password, forbidden symbols, etc.) will be returned from the block associated to the `check_parameter` method. Depending on the type of error, the appropiate HTML/erb content will be assigned to an
instance variable that will be used as the response body in the route defined in the main app file `buzzle.rb`, while displaying a flash error message. If no input errors are found by `check_parameter`, no values will be assigned to the error-capturing instance variable, `@input_error`. The main advantage of defining a custom `check_parameter` method is that, analyzing the return value of its code block, we can use it to validate any input in any other filter. For example, this is the filter for the `/new_user` `POST` request:

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
If `@input_errors` is assigned to a value (not `nil`), it will become the route's return value, via the `||` logical operator, and thus the body of the following HTTP request; but, if no errors were found (having a `nil` value), then the main code of the route will be executed. To illustrate this approach even more, here it is another example of the filter for the `POST` HTTP request to send new values when editing a board, and the corresponding route:

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
Expressed in plain words, this cascade-like structure means: if no errors were found in the board identifier, nor the user was not authorized to edit this board, nor there were errors in the new board values, the main route code can be executed. This approach makes, in my opinion, the routes much cleaner and easy to follow along, while keeping a valuable flexibility and the separation of concerns between the different validation subroutines, and the main, expected code to run within each route.


## The database

## Other design choices



