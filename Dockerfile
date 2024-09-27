# Stage 1: Build the application with dependencies
FROM ruby:3.2-alpine as builder

# Install build dependencies for bcrypt and other native gems
RUN apk add --no-cache build-base \
                          postgresql-dev \
                          linux-headers \
                          libc-dev \
                          make \
                          g++ \
                          openssl-dev

# Set the working directory inside the builder container
WORKDIR /usr/src/app

# Copy the Gemfile and Gemfile.lock first to leverage Docker's caching
COPY Gemfile Gemfile.lock ./

# Install bundler and then the gems using bundler
RUN gem install bundler && bundle config set --local without 'development test' && bundle install

# Copy the rest of the application code
COPY . .

# Stage 2: Create a smaller image with only the necessary files
FROM ruby:3.2-alpine

# Install runtime dependencies required to run the app and the PostgreSQL client library
RUN apk add --no-cache libstdc++ libgcc postgresql-libs bash openssl

# Set the working directory inside the final container
WORKDIR /usr/src/app

# Copy the installed gems from the builder stage
COPY --from=builder /usr/local/bundle /usr/local/bundle

# Copy the application code from the builder stage
COPY --from=builder /usr/src/app /usr/src/app

RUN adduser -D buzzle-user
USER buzzle-user
WORKDIR /home/buzzle-user

COPY --chown=buzzle-user . ./

# Command to run the Sinatra application using `bundle exec`
CMD ["bundle", "exec", "rackup", "--host", "0.0.0.0", "--port", "4567"]
