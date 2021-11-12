FROM ruby:2.6.6-alpine

RUN mkdir /app
WORKDIR /app
COPY . .
RUN apk add build-base
RUN gem install bundler:2.1.2
RUN bundle install
ENV RUBYOPT=-W0 
CMD bundle exec ruby run.rb
