# Pagination settings:
MAX_BOARDS_PER_PAGE ||= 6
MAX_MESSAGES_PER_PAGE ||= 3

# Queries:

# SELECT queries:

COUNT_BOARDS ||= 'SELECT id FROM boards'.freeze
COUNT_BOARD_MESSAGES ||= 'SELECT id FROM board_messages WHERE board_id = $1'.freeze
COUNT_CONVERSATIONS ||= 'SELECT id FROM conversations WHERE user_a_id = $1 OR user_b_id = $1'.freeze
COUNT_CONVERSATION_MESSAGES ||= 'SELECT id FROM private_messages WHERE conversation_id = $1'.freeze
COUNT_HISTORY ||= <<~SQL.rstrip.freeze
  SELECT board_messages.id
  FROM board_messages
  WHERE board_messages.author_id = $1
  ORDER BY posted_on DESC
SQL
COUNT_SEARCH_RESULTS ||= 'SELECT id FROM board_messages WHERE content ILIKE $1'.freeze
MESSAGES_UNREAD ||= 'SELECT id FROM private_messages WHERE read = false AND receiver_id = $1'.freeze
LOAD_USERS ||= 'SELECT id, username FROM users'.freeze
TOP_USERS ||= 'SELECT id, username, about_me, portrait FROM users ORDER BY score DESC LIMIT 3'.freeze
LAST_BOARD_MESSAGES ||= <<~SQL.rstrip.freeze
  SELECT boards.id AS board_id, title AS board_title, content FROM boards
  JOIN board_messages ON boards.id = board_messages.board_id
  ORDER BY board_messages.posted_on DESC
  LIMIT 3;
SQL
FIND_LAST_PRIVATE_MESSAGE ||= <<~SQL.rstrip.freeze
  SELECT * FROM private_messages 
  WHERE sender_id = $1 AND receiver_id = $2
  ORDER BY created_on DESC 
  LIMIT 1
SQL
USER_INFO_BY_USERNAME ||= 'SELECT * FROM users WHERE username = $1'.freeze
USER_INFO_BY_ID ||= 'SELECT * FROM users WHERE id = $1'.freeze
FIND_USER_ID ||= 'SELECT id FROM users WHERE username = $1'.freeze
FIND_BOARD ||= 'SELECT id FROM boards WHERE id = $1'.freeze
CONVERSATION_INFO ||= 'SELECT * FROM conversations WHERE id = $1'.freeze
ALL_BOARDS ||= <<~SQL.rstrip.freeze
SELECT 
  boards.*, 
  users.username AS author_username,
  (SELECT content
    FROM board_messages 
    WHERE board_id = boards.id 
    ORDER BY board_messages.posted_on DESC 
    LIMIT 1 ) AS last_message,
  (SELECT posted_on
    FROM board_messages 
    WHERE board_id = boards.id 
    ORDER BY board_messages.posted_on DESC 
    LIMIT 1 ) AS last_message_posted
  FROM boards
  LEFT JOIN users ON boards.author_id = users.id
  ORDER BY last_message_posted DESC NULLS LAST
  LIMIT #{MAX_BOARDS_PER_PAGE}
  OFFSET $1
SQL
BOARD_INFO ||= 'SELECT * FROM boards WHERE id = $1'.freeze
FIND_BOARD_MESSAGE ||= 'SELECT * FROM board_messages WHERE id = $1'.freeze
BOARD_MESSAGES ||= <<~SQL.rstrip.freeze
  SELECT 
    title AS board_title, 
    description AS board_description, 
    board_messages.*, 
    users.username AS author_username,
    boards.author_id AS board_author_id
  FROM boards
  LEFT JOIN board_messages ON board_messages.board_id = boards.id
  LEFT JOIN users ON board_messages.author_id = users.id
  WHERE boards.id = $1
  ORDER BY posted_on
  LIMIT #{MAX_MESSAGES_PER_PAGE}
  OFFSET $2
SQL
CONVERSATION_EXISTS ||= <<~SQL.rstrip.freeze
  SELECT id 
  FROM conversations
  WHERE (user_a_id = $1 AND user_b_id = $2) OR 
        (user_a_id = $2 AND user_b_id = $1);
SQL
LOAD_CONVERSATIONS ||= <<~SQL.rstrip.freeze
  SELECT 
    conversations.*,
    (SELECT username FROM users WHERE id = user_a_id) AS user_a_name,
    (SELECT username FROM users WHERE id = user_b_id) AS user_b_name
  FROM conversations
  WHERE user_a_id = $1 OR user_b_id = $1
  ORDER BY last_message DESC
  LIMIT #{MAX_MESSAGES_PER_PAGE}
  OFFSET $2
SQL
LOAD_PRIVATE_MESSAGES ||= <<~SQL.rstrip.freeze
  SELECT 
    private_messages.created_on, 
    private_messages.sender_id,
    (SELECT username FROM users WHERE id = sender_id) AS sender_username, 
    private_messages.receiver_id,
    (SELECT username FROM users WHERE id = receiver_id) AS receiver_username, 
    private_messages.content 
  FROM private_messages
  JOIN conversations ON private_messages.conversation_id = conversations.id
  WHERE conversation_id = $1
  ORDER BY private_messages.created_on DESC
  LIMIT #{MAX_MESSAGES_PER_PAGE}
  OFFSET $2
SQL
LOAD_HISTORY ||= <<~SQL.rstrip.freeze
  SELECT board_messages.*, 
    boards.title AS board_title,
    boards.color AS board_color
  FROM board_messages
  JOIN boards ON board_messages.board_id = boards.id
  WHERE board_messages.author_id = $1
  ORDER BY posted_on DESC
  LIMIT #{MAX_MESSAGES_PER_PAGE}
  OFFSET $2
SQL
VALID_NEW_USERNAME ||= 'SELECT id FROM users WHERE id != $1 AND username = $2'.freeze
SEARCH_MESSAGES ||= <<~SQL.rstrip.freeze
  SELECT 
    board_messages.*,
    boards.title AS board_title,
    boards.color AS board_color,
    users.username AS author,
    users.id AS author_id
  FROM board_messages
  JOIN boards ON board_messages.board_id = boards.id
  LEFT JOIN users ON board_messages.author_id = users.id
  WHERE content ILIKE $1
  ORDER BY board_messages.posted_on DESC
  LIMIT #{MAX_MESSAGES_PER_PAGE}
  OFFSET $2
SQL

# INSERT queries:

ADD_NEW_USER ||= <<~SQL.rstrip.freeze
  INSERT INTO users 
  (username, first_name, last_name, password, about_me, portrait) 
  VALUES ($1, $2, $3, $4, $5, $6)
SQL
ADD_NEW_BOARD ||= 'INSERT INTO boards (title, description, author_id, color) VALUES ($1, $2, $3, $4)'.freeze
ADD_MESSAGE ||= 'INSERT INTO board_messages (content, author_id, board_id) VALUES ($1, $2, $3)'.freeze
CREATE_CONVERSATION ||= 'INSERT INTO conversations (user_a_id, user_b_id) VALUES ($1, $2)'.freeze
SEND_PRIVATE_MESSAGE ||= <<~SQL.rstrip.freeze
  INSERT INTO private_messages 
    (content, sender_id, receiver_id, conversation_id)
  VALUES ($1, $2, $3, (SELECT id 
                      FROM conversations
                      WHERE (user_a_id = $2 AND user_b_id = $3) OR 
                            (user_a_id = $3 AND user_b_id = $2)
                      ))
SQL

# UPDATE queries:

SET_MESSAGES_READ ||= <<~SQL.rstrip.freeze
  UPDATE private_messages
  SET read = true 
  WHERE receiver_id = $1 AND conversation_id = $2
SQL
ADD_SCORE ||= 'UPDATE users SET score = score + $1 WHERE id = $2'.freeze
EDIT_BOARD_MESSAGE ||= 'UPDATE board_messages SET content = $1 WHERE id = $2'.freeze
UPDATE_CONVERSATION ||= <<~SQL.rstrip.freeze
  UPDATE conversations
  SET last_message = now()
  WHERE (user_a_id = $1 AND user_b_id = $2) OR
        (user_a_id = $2 AND user_b_id = $1)
SQL
EDIT_BOARD ||= <<~SQL.rstrip.freeze
  UPDATE boards
  SET
    title = $1,
    description = $2,
    color = $3
  WHERE id = $4
SQL
UPDATE_PROFILE_DATA ||= <<~SQL.rstrip.freeze
  UPDATE users
  SET 
    username = $2,
    first_name = $3,
    last_name = $4,
    about_me = $5,
    portrait = $6
  WHERE id = $1
SQL
UPDATE_PASSWORD ||= 'UPDATE users SET password = $2 WHERE id = $1'.freeze

# DELETE queries:

DELETE_CONVERSATION ||= 'DELETE FROM conversations WHERE id = $1'.freeze
DELETE_BOARD ||= 'DELETE FROM boards WHERE id = $1'.freeze
DELETE_BOARD_MESSAGE ||= 'DELETE FROM board_messages WHERE id = $1'.freeze
DELETE_USER ||= 'DELETE FROM users WHERE id = $1'.freeze
PURGE_OLD_BOARDS ||= "DELETE FROM boards WHERE author_id IS NULL AND created_on < now() - INTERVAL '1 DAY'".freeze
