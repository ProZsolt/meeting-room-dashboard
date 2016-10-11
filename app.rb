require 'rubygems'
require 'sinatra/base'
require 'sinatra-websocket'
require 'google/apis/calendar_v3'
require 'google/apis/admin_directory_v1'
require 'json'
require 'dotenv'
require 'rufus/scheduler'
require_relative 'helpers/service_account_credentials.rb'


class MeetingRoomDashboard < Sinatra::Base
  set :server, 'thin'
  set :sockets, Hash.new([])

  Dotenv.load

  set :domain, ENV['MRD_DOMAIN']

  use Rack::Auth::Basic, "Restricted Area" do |username, password|
    username == ENV['MRD_USER'] and password == ENV['MRD_PASSWORD']
  end

  Rufus::Scheduler.new.cron '5 0 * * *' do
    refresh_all
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
      address: "https://#{settings.domain}/refresh/#{calendar_id}",
      token: 'ThisIsAValidMessage',
      type: 'web_hook',
      #expiration: ''
    )
    calendar = Google::Apis::CalendarV3::CalendarService.new
    calendar.authorization = credentials_for Google::Apis::CalendarV3::AUTH_CALENDAR
    calendar.watch_event(calendar_id, channel)
  end

  def watch_all
    get_resources.items.each do |resource|
      watch_calendar resource.resource_email
    end
  end

  def refresh_all
    settings.sockets.each do |calendar_id, sockets|
      events = get_events(calendar_id)
      EM.next_tick{ sockets.each{|s| s.send(events)} }
    end
  end

  get '/' do
    @resources = get_resources
    erb :rooms
  end

  get '/calendar/:calendar_id' do |calendar_id|
    @resources = get_resources
    return erb :dashboard unless request.websocket?
    request.websocket do |ws|
      ws.onopen do
        settings.sockets[calendar_id] += [ws]
        EM.next_tick{ ws.send(get_events(calendar_id)) }
      end
      ws.onmessage do |msg|
        create_event(calendar_id, msg.to_i)
        EM.next_tick{ ws.send(get_events(calendar_id)) } # @todo remove this after the update hook is done
      end
      ws.onclose do
        settings.sockets[calendar_id].delete(ws)
      end
    end
  end

  get '/refresh/:calendar_id' do |calendar_id|
    events = get_events(calendar_id)
    EM.next_tick{ settings.sockets[calendar_id].each{|s| s.send(events)} }
  end
end
