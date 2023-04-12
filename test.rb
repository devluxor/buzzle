



def to_flash_message(message)
  validation = message[0...message.index('_')] 
  input_element = message[message.index('_') + 1..-1]
  
  if validation == 'valid'
    to_error_message(validation, input_element.gsub('_', ' ' ))
  else
    to_success_message(input_element.to_sym)
  end
end

def to_error_message(validation, input_element)
  case validation
  when 'invalid'
    "Please, enter a valid #{input_element}"
  when 'forbidden'
    "The #{input_element} introduced contains forbidden characters"
  when /long|short/
    "The #{input_element} introduced is too #{validation}"
  when 'unmatched'
    "The passwords introduced don't match"
  when 'taken'
    'Sorry, the username introduced is already taken'
  when 'incorrect'
    'The password introduced is not correct'
  when 'empty'
    "Please, enter #{input_element}"
  when 'inexistent'
    "The #{input_element} introduced does not exist"
  when 'unauthorized'
    'You are not authorized to do that'
  end
end

def to_success_message(input_element)
  case input_element
  when 'login'
    'Welcome again!'
  when 'logout'
    'Good-bye!'
  when 'new user'
    'Welcome!'
  when 'board'
    'Board created successfully!'
  when 'board edit'
    'Board edited successfully!'
  when 'message'
    'Message sent successfully!'
  when 'delete board'
    'The board will be automatically deleted in 24 hours'
  when 'delete conversation'
    'The conversation was deleted successfully!'
  when 'update user'
    'Your data has been updated successfully!'
  when 'delete user'
    'Your account was deleted successfully'
  end
end

m = 'invalid_something_other'

fm = to_flash_message(m)
