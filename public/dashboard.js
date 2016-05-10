
var json;

function update(){
  updateClock()
  updateRoomName(json["room_name"]);
  updateEvents(json["next_events"]);
  updateCurrent(json["current_event"]);
}

function updateRoomName(name){
  document.getElementById("room_name").firstChild.nodeValue = name;
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

function updateEvents(events){
  var string = "";
  events.forEach(function(event) {
    name = event["name"];
    start = parseGoogleDate(event["start"]);
    end = parseGoogleDate(event["end"]);
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
function updateCurrent(event){
  document.getElementById("current_event").firstChild.nodeValue = event["name"];
  start = new Date();
  end = parseGoogleDate(event["end"]);
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
    console.log(json);
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
