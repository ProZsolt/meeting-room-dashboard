FROM alpine:3.4

ENV APP_HOME /opt/cheppers/meeting-room-dasboard
COPY . $APP_HOME
WORKDIR $APP_HOME

RUN apk add --no-cache g++ make supervisor ruby ruby-dev ruby-io-console ruby-json ca-certificates && \
    echo "gem: --no-rdoc --no-ri" > ~/.gemrc && \
    gem install bundler && \
    bundler --without development

EXPOSE 80
CMD ["bundle", "exec", "puma", "config.ru", "-p80"] 
