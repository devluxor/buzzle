CREATE TABLE users (
  id int PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  username varchar(30) UNIQUE NOT NULL,
  first_name varchar(40) NOT NULL,
  last_name varchar(40),
  password char(60) NOT NULL CHECK (length(password) = 60),
  score integer DEFAULT 0,
  about_me varchar(250),
  portrait varchar(25) NOT NULL DEFAULT 'bear.png' CHECK (portrait LIKE '%.png'),
  created_on timestamp NOT NULL DEFAULT now()
);

INSERT INTO users
(username, first_name, last_name, password, score, about_me, portrait, created_on)
VALUES
('John', 'John', 'Lennon', 
'$2a$12$zRY6TtjDGb9Ti3OkPdZIS.G3tNWawBqRHpSato2Ly75u/fwq3ybNm',
189, 'Musician. From Liverpool, UK', 'snake.png', '1963-04-12 17:22:47.493425' ),
('Paul', 'Paul', 'McCartney',
'$2a$12$gSGhIE69SyHnIeKbY1e/XeliywTluu9rhtFoNSpfOBO4kOPv2d6e6',
139, 'Just a simple boy from Liverpool.', 'bear.png', '1963-04-11 18:22:47.493425' ),
('George', 'George', 'Harrison', 
'$2a$12$NWvZ9InR4A1lvKxY5dHuX.fDwgo/hTBaZ343WUPfaPfQreZTRhPTe',
209, 'Something in the way...', 'cat.png', '1963-05-12 17:22:47.493425' ),
('Ringo', 'Ringo', 'Starr', 
'$2a$12$zRY6TtjDGb9Ti3OkPdZIS.G3tNWawBqRHpSato2Ly75u/fwq3ybNm',
169, 'Friend of everybody', 'dog.png', '1963-04-09 17:22:47.493425' );

CREATE TABLE boards (
  id int PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  author_id integer NULL REFERENCES users (id) ON DELETE SET NULL,
  created_on timestamp NOT NULL DEFAULT now(),
  title varchar(100) NOT NULL,
  description varchar(100) DEFAULT NULL,
  color varchar(30) NOT NULL DEFAULT ('orange')
);

INSERT INTO boards 
(author_id, created_on, title, description, color)
VALUES
(4, '1967-05-26 17:22:47.493425', 'I love our new album!', 'But I don''t know who that Sgt. is...', 'green'),
(2, '1965-08-06 17:22:47.493425', 'Help!', 'I just need somebody...', 'red'),
(3, '1969-04-12 17:22:47.493425', 'Abbey Road', 'Any ideas for the cover?', 'blue'),
(1, '1966-11-09 17:22:47.493425', 'Good news, lads!!', 'I met a girl, she''s Japanese...', 'purple');

CREATE TABLE board_messages (
  id int PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  board_id integer NOT NULL REFERENCES boards (id) ON DELETE CASCADE,
  author_id integer REFERENCES users (id) ON DELETE SET NULL,
  posted_on timestamp NOT NULL DEFAULT now(),
  content varchar(1000) NOT NULL
);

INSERT INTO board_messages 
(board_id, author_id, posted_on, content)
VALUES
(4, 2, '1967-05-29 17:22:47.493425', 'I think I don''t like her'),
(2, 1, '1965-12-06 17:22:47.493425', 'What do you need, Paul?'),
(3, 3, '1969-04-21 17:22:47.493425', 'Something simple, just the four of us'),
(1, 4, '1968-11-09 17:22:47.493425', 'Haha, he must be one of those people...'),
(2, 2, '1967-12-31 17:22:47.493425', 'Help me if you can, I''m feeling down'),
(1, 2, '1967-12-19 17:22:47.493425', 'Even Marylin''s there!'),
(1, 4, '1966-12-19 17:22:47.493425', 'I like John''s moustache'),
(1, 1, '1966-12-29 17:22:47.493425', 'Look, Edgar Allan Poe!'),
(4, 1, '1969-11-09 17:22:47.493425', 'Friends, I''ve got to tell you something...');

CREATE TABLE conversations (
  id int PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  user_a_id integer REFERENCES users (id) ON DELETE CASCADE,
  user_b_id integer REFERENCES users (id) ON DELETE CASCADE,
  last_message timestamp NOT NULL DEFAULT now()
);

INSERT INTO conversations 
(user_a_id, user_b_id, last_message)
VALUES
(1, 2, '1970-01-02 19:22:12.321211'),
(1, 3, '1970-01-01 19:22:12.321211'),
(1, 4, '1970-01-01 19:22:12.321211');

CREATE TABLE private_messages (
  id int PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
  sender_id integer REFERENCES users (id) ON DELETE CASCADE,
  receiver_id integer REFERENCES users (id) ON DELETE CASCADE,
  conversation_id integer NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
  created_on timestamp NOT NULL DEFAULT now(),
  content varchar(1000) NOT NULL,
  read boolean NOT NULL DEFAULT false
);

INSERT INTO private_messages
(sender_id, receiver_id, conversation_id, created_on, content, read)
VALUES
(1, 2, 1, '1970-01-01 19:22:12.321211', 'Goodbye Paul 😢', false ),
(1, 3, 2, '1970-01-01 19:22:12.321211', 'Goodbye George 😢', false ),
(1, 4, 3, '1970-01-01 19:22:12.321211', 'Goodbye Ringo 😢', false ),
(2, 1, 1, '1970-01-02 19:22:12.321211', 'Goodbye John 😢', false );


