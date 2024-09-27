# Welcome to Buzzle!

## What is Buzzle?

Buzzle is a color-based, easy-to-use message board web application that also provides a private channel for the communication between users, with an informal, friendly user interface.

## Features

This application allows the users to create, edit and delete their own message boards, on which every user with an account can read and post messages, customize his/her own profile, read other's profiles, send private messages to each other, search for terms in every public message posted, access to a history of every message posted by them, update the password and any profile data, and delete his/her account. 

Buzzle also includes a live feed with the last messages posted, and another with the users with more activity on the application thanks to a score system. There is also a notification system that alerts the user when there are unread private messages. In case the user forgets to delete his/her boards before he or she deletes the account, the application will delete automatically any board that belong to that deleted account after a delay of 24 hours, so other users have the time to read the messages on that board. Every page that has boards or messages, private or public, includes a pagination system, and a specific way to order the content.

When the user reads a message posted by another user, the username can be clicked to access directly to the user's profile; each profile includes a button to start a private conversation with that user. The user can choose, and later change, a profile picture among a pre-defined list based on the `.png` files present in `./public/images/profile`; in case more files are added later, the application will dynamically update the list of pictures available. 

Every message in the history of messages and in the search results pages can be clicked, so the user can see the original message in its context, and every search result or history element has the color of the board on which its content was posted. Each message, including private messages, has a dynamically assigned 'time-passed' type of indicator, so the user can know when it was sent or posted, from seconds to minutes, days, weeks, months and years of precision. Although the private messages can't be deleted directly, the conversation can be deleted by their participants, and every private message associated with that particular conversation between the two users will also be deleted accordingly. Every change is reflected on the database; also, with every possibility of permanent data removal on the database, the user will be alerted with a confirmation message.

The application is protected against bad user input, including possible injection attacks, with a double validation system in both the backend and the fronted. The backend input validation system is based on a series of route-specific filters and methods that specifically analyze every case and inform the user what went wrong via a flash message that will disappear after a few seconds. This validation system does not only detect errors in parameters sent via forms, but also in every identifier in the URL, including those parameters belonging to the pagination system. On top of the backend validation, each form includes an HTML-based validation system, to add an extra layer of security. The passwords are never stored as they are, but are encrypted before inserting them in the database. SQL queries have been optimized up to a certain point (n+1 queries were substituted by single queries, etc.)

For more information about the design decisions, SQL specifics, and more technical details, please, don't hesitate to read the file `DESIGN.md` in this same folder. For a general layout of the application, please see `MAP.txt`

## Software requirements

This application has been built and run with **Ruby v3.2.5**, using **Sinatra v3.0.4** along the Puma server v6.1.1. **PostgreSQL v12.14** was used to create and interact with the database. For more details about dependencies, please see the `Gemfile` in this same folder.

The application was created using Visual Studio Code v1.75 on Ubuntu inside a WSL2 virtual machine, Windows 10.0.19044.

The following internet browsers were used to test the application:

| **Explorer**        | **Version**       | **Backend**         | **Frontend**        | **Overall Assessment** |
|-----------------|---------------|-----------------|-----------------|--------------------|
| Google Chrome   | 112.0.5615.50 | No issues found | No issues found |     ✅  |
| Mozilla Firefox | 112.0         | No issues found | No issues found |     ✅  |
| Opera           | 112.0.1722.39 | No issues found | No issues found |     ✅  |
| Microsoft Edge  | 12.5          | No issues found | No issues found |     ✅  |

## How to run the application

### Run the app as a container using Docker:

Simply, within the app's root folder, run:

```sh
docker compose up
```

Once the image is built and running on your computer, visit <http://localhost:4567>

### Old-school way

Inside the `buzzle/` folder, run `bundle install` to install all the Gem dependencies:

```bash
bundle install
```

Then, to initialize the database in your system, execute:

```bash
createdb buzzle && psql -d buzzle < ./db/schema.sql
```

This will also add some seed data to the database as a sample; these are the sample users' credentials:

| Username | Password |
|----------|----------|
| John     | 123      |
| Paul     | 123      |
| George   | 123      |
| Ringo    | 123      |

These sample users have created boards, posted messages on them, sent or being sent private messages, etc.
I encourage the reader to create a new user account and interact with them, or to log in with any of these accounts' credentials and explore the possibilities of the application.

To start the app, execute the following command on the terminal, inside the main `buzzle/` directory:

```bash
$ ruby buzzle.rb
```

As an option, in order to safely load the correct version of certain applications, you can also execute:

```bash
$ bundle exec ruby buzzle.rb
```

Finally, to access the app, use the default URL <http://localhost:4567> in your browser of choice.


## Configuration

The app has a few easily configurable options:

- To change the pagination settings, for example, when using multiple monitors or ultrawide devices, you can alter the values assigned to the `MAX_BOARDS_PER_PAGE`, and `MAX_MESSAGES_PER_PAGE` constants in `./db/queries.rb`. Changing this values dynamically is a possibility that will come with the proper JavaScript knowledge in the future.

- To change the points each activity adds to the users' score, alter the values assigned to the `BOARD_MESSAGE`, `PRIVATE_MESSAGE`, and `NEW_BOARD` constants in `./db/database_interaction.rb`.

- To add more custom profile portraits, the user will only have to add a `.png` file to the `./public/images/profile` folder; the application will update the available options automatically.








