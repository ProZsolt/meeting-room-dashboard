var json;
var roomName;
var currentEvent;
var nextEvents;

function update(){
  updateClock()
  updateRoomName();
  updateEvents();
  updateCurrentEvent();
  updateNextEvents()
}

function updateEvents(){
  roomName = json["room_name"];
  var now = new Date();
  var events = json["events"];
  console.log(events);
  for (i = 0; parseGoogleDate(events[i]["end"]) < now; i++){
    events.shift;
  }
  console.log(events);
  if (parseGoogleDate(events[0]["start"]) < now){
    currentEvent = events.shift();
  } else{
    currentEvent = {"name": "Available", "end": events[0]["start"]};
  }
  nextEvents = events;
}

function updateRoomName(){
  document.getElementById("room_name").firstChild.nodeValue = roomName;
}

function parseGoogleDate(d) {
  var googleDate = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})([+-]\d{2}):(\d{2})$/;
  var m = googleDate.exec(d);
  var year   = +m[1];
  var month  = +m[2];
  var day    = +m[3];
  var hour   = +m[4];
  var minute = +m[5];
  var second = +m[6];
  var tzHour = +m[7];
  var tzMin  = +m[8];
  var tzOffset = new Date().getTimezoneOffset() + tzHour * 60 + tzMin;

  return new Date(year, month - 1, day, hour, minute - tzOffset, second);
}

function timeStringFromDateTime(dateTime){
  var hours = dateTime.getHours();
  var minutes = dateTime.getMinutes();
  var seconds = dateTime.getSeconds();

  minutes = (minutes < 10 ? "0" : "") + minutes;
  seconds = (seconds < 10 ? "0" : "") + seconds;

  return hours + ":" + minutes + ":" + seconds;
}

function updateNextEvents(){
  var string = "";
  nextEvents.forEach(function(event) {
    var name = event["name"];
    var start = parseGoogleDate(event["start"]);
    var end = parseGoogleDate(event["end"]);
    string = string
      + timeStringFromDateTime(start)
      + " - "
      + timeStringFromDateTime(end)
      + " "
      + name
      + "<br/>";
  });
  document.getElementById("next_events").firstChild.nodeValue = string;
}

function updateCurrentEvent(){
  document.getElementById("current_event").firstChild.nodeValue = currentEvent["name"];
  start = new Date();
  end = parseGoogleDate(currentEvent["end"]);
  remaining = end - start;
  hours = Math.floor(remaining / 3600000);
  mins = Math.floor((remaining % 3600000) / 60000);
  remainingString = "For"

  if (remaining < 60000){
    remainingString = remainingString + " less than a min"
  }
  else {
    if (hours == 1){
      remainingString = remainingString + " 1 hour"
    } else if (hours > 1) {
      remainingString = remainingString + " " + hours + " hours"
    }

    if (mins == 1){
      remainingString = remainingString + " 1 min"
    } else if (mins > 1) {
      remainingString = remainingString + " " + mins + " mins"
    }
  }
  remainingString = remainingString + "."
  document.getElementById("remaining").firstChild.nodeValue = remainingString;
}

function webSocketSetup(){
  function onMessage(data){
    json = JSON.parse(data);
    update();
  }

  var protocol = location.protocol === 'https:' ? 'wss' : 'ws'

  var ws       = new WebSocket(protocol + '://' + window.location.host + window.location.pathname);
  ws.onopen    = function(){};
  ws.onclose   = function(){};
  ws.onmessage = function(message){onMessage(message.data);};
}

function updateClock(){
  var currentTime = new Date();
  document.getElementById("clock").firstChild.nodeValue = timeStringFromDateTime(currentTime);
}
