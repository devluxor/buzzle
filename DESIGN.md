## An overview of the overall functioning of the application

A Sinatra application is basically a collection of 'routes' or method/URL _patterns_ of HTTP requests sent from the client to the server, and the definition of the corresponding HTTP response to those requests; in other words, for every request with a path defined in a route or _pattern_, with a specific HTTP method, there is a behavior and a response, defined inside each route block.

For example, if we want the user to see the login page, we define a route with the HTTP method used to send that request to the server, `GET`. Then, we add a pattern with the desired URL path, `/login`, and we define a block that will contain the behavior that will follow the server after a request with these characteristics. The return value of the block will determine, at least, the response body passed on to the HTTP client. In Buzzle, most of the time this will be a string containing HTML code defined in a `.erb` template, loaded by an `erb` method; it can also be a redirection to other defined route.

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

After comparing different approaches and possible structures for Sinatra applications, I opted out the more complex ones, and chose a classic style, but with a pseudo-modular flavor. The classic style, the one without file subclassing, based on traditional ruby file loading, serves the purpose of the application very well and without setbacks, as I didn't need more than one Sinatra application per Ruby process. Nevertheless, encouraged by the Sinatra's flexibility and the clarity of its documentation, I decided to have a clear separation of concerns and tasks, following the 'one class per file' model, and I created a different file for each different aspect of the application: one file for the `before` filters, one file for the user validation helper methods, etc. This way, although keeping the classic Sinatra style, the application becomes more easily readable, configurable and maintainable.


## Database design and optimization

The database is composed by five tables representing five types of entities: _users_, _boards_, _board messages_, _private messages_ and _conversations_. A user is represented by a row in the `users` table that contains all the account information; a row in the `boards` table represents a message board posted by a single user, and has all the information about that board, like when it was posted, its title and description, its color, etc.; `board_messages` contains every single message posted in any board, with all the appropriate information; one row in `private_messages` represents each message sent by a user to another user, along all its information too. The `conversations` table, on the other hand, represents _a single channel of communication between two users_, or a private conversation between a user 'a' and a user 'b'; the table contains a primary key for the conversation, identifiers for both users, and the timestamp of the last message sent by 'a' to 'b' or vice versa. Of course, every time a private message is sent, the program checks if there's already a conversation going on between sender and receiver: if there is, it updates the timestamp in the corresponding `conversations` row, and sends the message; if there is not, it creates a new conversation.

Relationships between entities:

| **Entity A**  | **Entity B**        | **Type of Relationship** |
|--------------|-----------------|----------------------|
| User         | Board           | 1:M                  |
| Board        | Board Message   | 1:M                  |
| User         | Private Message | 1:M                  |
| Conversation | User            | M:M                  |

Probably, the most arguable point in this approach is the inclusion of a `conversations` table. Why not just grouping the private messages by user 'a' and user 'b' to load all the ongoing conversations between the current user and others? For example, we could construct a query with something like:

```sql
  SELECT 
    MAX(private_messages.created_on) AS last_message, 
    private_messages.sender_id,
    private_messages.receiver_id,
    (SELECT username FROM users WHERE id = sender_id) AS sender_name,
    (SELECT username FROM users WHERE id = receiver_id) AS receiver_name
  FROM private_messages
  WHERE sender_id = $1 OR receiver_id = $1
  GROUP BY sender_id, receiver_id
  ORDER BY last_message DESC
```

This would group the messages by conversations without the need for a `conversations` table. However, how could we uniquely identify the conversation between the two users? We could do that by using the primary key of the user that is not the current user, but then, the logic in the queries would be more complicated, and we would have to have an extra step of validation in our program. Also, in case we wanted to, for instance, include a 'user stats' kind of page, the queries to extract the data from all the different conversations between different users would be also more intricate. My point is that, after balancing out all the pros and cons, I finally opted for having a `conversations` table to represent this entity, but I am not oblivious to the possible trade-offs that could come by when the app scales, and I am open to discuss this decisions and change the design accordingly if good arguments come up.

I've

## Other design choices

On the main `'/'` page, the boards are sorted by last activity, from more recent activity to latest. The boards with activity (messages posted on them),
will always have priority over those with no messages yet. The board messages are sorted from older to newer, but the user is automatically directed to the last page of the board when the board is clicked, to see its latest activity. The private messages order is inverted, from newer to older. This is by design.

All the user data can be updated, even the password, and the account can be deleted by the user. Every board posted by a user can be accessed by everyone, but it can only be edited and deleted by its author, and the same with board messages: anyone can post anywhere, but only the message author can edit or delete the message. Single private messages can't be deleted individually, but the whole conversation can be deleted by any of its participants; I thought this made more sense to the application, and it is in concordance with other common applications. Naturally, before every destructive action with an effect in the database, the user is alerted by a confirmation message: if the users confirms, the action will take place. Also, every method in Ruby with a permanent, altering effect is marked with an exclamation sign `!` at the end of its name (for example, the `DatabaseInteraction#add_board!` method).

One aspect that I'd like to talk about is when a user deletes his or her account, but there are still boards posted by him or her. I thought that it would be interesting that, instead of removing every board posted by the owner of the deleted account immediately, why don't leave that board for a day, in order to let other users save their board messages. This is achieved by allowing `NULL` author identifier foreign keys in the `boards` table, and executing a special query that is sent to the database each time a user logs in:

```sql
DELETE FROM boards WHERE author_id IS NULL AND created_on < now() - INTERVAL '1 DAY'
-- I enjoyed the discovery of the INTERVAL() function. It's very useful in cases like these.
```

Another feature I wanted my application to have is a way to notify the user that he or she has unread messages. This was achieved by the inclusion of an extra `read` column in the `private_messages` table, with a boolean type. `false` by default, it is updated to `true` the time the conversation that the private messages refers to is accessed. This was another reason to have a `conversations` table in the database. When the user identifier is the same as any private message's receiver identifier, with a `read` flag of `false`, a little exclamation sign is shown over the 'Conversations' icon on the left navigation bar.
