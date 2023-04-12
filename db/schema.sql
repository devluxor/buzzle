CREATE TABLE users (
  id serial PRIMARY KEY,
  username varchar(30) UNIQUE NOT NULL,
  first_name varchar(40) NOT NULL,
  last_name varchar(40),
  password char(60) NOT NULL CHECK (length(password) = 60),
  score integer DEFAULT 0,
  about_me varchar(250),
  portrait varchar(25) NOT NULL DEFAULT 'bear.png' CHECK (portrait LIKE '%.png'),
  created_on timestamp NOT NULL DEFAULT now()
);

CREATE TABLE boards (
  id serial PRIMARY KEY,
  author_id integer NULL REFERENCES users (id) ON DELETE SET NULL,
  created_on timestamp NOT NULL DEFAULT now(),
  title varchar(100) NOT NULL,
  description varchar(100) DEFAULT NULL,
  color varchar(30) NOT NULL DEFAULT ('orange')
);

CREATE TABLE board_messages (
  id serial PRIMARY KEY,
  board_id integer NOT NULL REFERENCES boards (id) ON DELETE CASCADE,
  author_id integer REFERENCES users (id) ON DELETE SET NULL,
  posted_on timestamp NOT NULL DEFAULT now(),
  content varchar(1000) NOT NULL
);

CREATE TABLE conversations (
  id serial PRIMARY KEY,
  user_a_id integer REFERENCES users (id) ON DELETE CASCADE,
  user_b_id integer REFERENCES users (id) ON DELETE CASCADE,
  last_message timestamp NOT NULL DEFAULT now()
);

CREATE TABLE private_messages (
  id serial PRIMARY KEY,
  sender_id integer REFERENCES users (id) ON DELETE CASCADE,
  receiver_id integer REFERENCES users (id) ON DELETE CASCADE,
  conversation_id integer NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
  created_on timestamp NOT NULL DEFAULT now(),
  content varchar(500) NOT NULL,
  read boolean NOT NULL DEFAULT false
);

