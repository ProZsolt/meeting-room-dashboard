require 'rubygems'
require 'sinatra/base'
require 'faye/websocket'
require 'google/apis/calendar_v3'
require 'google/apis/admin_directory_v1'
require 'json'
require 'dotenv'
require 'rufus/scheduler'
require_relative 'helpers/service_account_credentials.rb'


class MeetingRoomDashboard < Sinatra::Base
  configure do
    Dotenv.load
    set :calendars, Array.new
    set :domain, ENV['MRD_DOMAIN']
    set :token, ENV['MRD_TOKEN']

    Rufus::Scheduler.new.cron '5 0 * * *' do
      settings.calendars.each do |calendar|
        events = get_events(calendar[:calendar_id])
        calendar[:sockets].each do |socket|
          socket.send(events)
        end
        if calendar[:channel].expiration.to_i/1000 - Time.now.to_i < 86400
          calendar[:channel] = watch_calendar(calendar[:calendar_id])
        end
      end
    end
  end

  def credentials_for(scope)
    ServiceAccountCredentials.new( json_key_file: ENV['MRD_JSON_KEY'],
                                   person: ENV['MRD_PERSON'],
                                   scope: scope
                                 )
  end

  def get_events(calendar_id)
    day_start = Date.today
    day_end = Date.today.next_day
    calendar = Google::Apis::CalendarV3::CalendarService.new
    calendar.authorization = credentials_for Google::Apis::CalendarV3::AUTH_CALENDAR
    g_events = calendar.list_events(calendar_id,
                                   single_events: true,
                                   order_by: 'startTime',
                                   time_min: day_start.rfc3339,
                                   time_max: day_end.rfc3339,
                                   time_zone: 'Europe/Budapest',
                                   fields: 'items(summary,start,end,attendees),summary')
    events = g_events.items
      .reject{ |e| e.attendees.find{|a| a.email == calendar_id}.response_status == 'declined'}
      .map do |event|
        {
          name: event.summary,
          start: event.start.date_time,
          end: event.end.date_time,
          attendees: event.attendees.reject(&:resource).map do |attendee|
            attendee.display_name || attendee.email
          end
        }
      end
    calendar_name = g_events.summary
    {room_name: calendar_name, events: events}.to_json
  end

  def create_event(calendar_id, duration)
    event_start = DateTime.now
    calendar = Google::Apis::CalendarV3::CalendarService.new
    calendar.authorization = credentials_for Google::Apis::CalendarV3::AUTH_CALENDAR
    event = {
       summary: 'Ad hoc Meeting',
       attendees: [{email: calendar_id}],
       start: {
         date_time: event_start.rfc3339
       },
       end: {
         date_time: (event_start + duration / 1440.0).rfc3339
       }
    }
    calendar.insert_event('primary', event, send_notifications: false)
  end

  def get_resources
    direcrory = Google::Apis::AdminDirectoryV1::DirectoryService.new
    direcrory.authorization = credentials_for Google::Apis::AdminDirectoryV1::AUTH_ADMIN_DIRECTORY_RESOURCE_CALENDAR_READONLY
    direcrory.list_calendar_resources('my_customer')
  end

  def watch_calendar(calendar_id)
    channel = Google::Apis::CalendarV3::Channel.new(
      id: SecureRandom.uuid,
      address: "https://#{settings.domain}/notifications",
      token: settings.token,
      type: 'web_hook',
    )
    calendar = Google::Apis::CalendarV3::CalendarService.new
    calendar.authorization = credentials_for Google::Apis::CalendarV3::AUTH_CALENDAR
    calendar.watch_event(calendar_id, channel)
  end

  get '/' do
    @resources = get_resources
    erb :rooms
  end

  get '/calendar/:calendar_id' do |calendar_id|
    if Faye::WebSocket.websocket?(request.env)
      ws = Faye::WebSocket.new(request.env)

      ws.on(:open) do |event|
        calendar = settings.calendars.find{ |calendar| calendar[:calendar_id] == calendar_id}
        if calendar
          calendar[:sockets] << ws
        else
          calendar = {
            calendar_id: calendar_id,
            sockets: [ws],
            channel: watch_calendar(calendar_id)
          }
          settings.calendars << calendar
        end
        ws.send(get_events(calendar_id))
      end

      ws.on(:message) do |msg|
        create_event(calendar_id, msg.data.to_i)
      end

      ws.on(:close) do |event|
        calendar = settings.calendars.find{ |calendar| calendar[:calendar_id] == calendar_id}
        calendar[:sockets].delete(ws)
      end

      ws.rack_response
    else
      erb :dashboard
    end
  end

  post '/notifications' do
    if request.env['HTTP_X_GOOG_CHANNEL_TOKEN'] == settings.token
      if request.env['HTTP_X_GOOG_RESOURCE_STATE'] == 'exists'
        channel_id = request.env['HTTP_X_GOOG_CHANNEL_ID']
        calendar = settings.calendars.find{ |calendar| calendar[:channel].id == channel_id}
        if calendar
          events = get_events(calendar[:calendar_id])
          calendar[:sockets].each do |socket|
            socket.send(events)
          end
        end
      end
      'OK'
    else
      status 401
      body '401 Unauthorized'
    end
  end
end
