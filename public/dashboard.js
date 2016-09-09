var json = "";

function update(){
  updateClock();
  if(json != ""){
    updateEvents();
  }
}

function updateEvents(){
  var now = new Date();
  var events = json["events"];
  while (events.length > 0 && parseGoogleDate(events[0]["end"]) < now){
    events.shift();
  }
  if(events.length == 0){
    updateCurrentEvent({"name": "Available", "end": "nil"});
    updateNextEvents([]);
  }else if(parseGoogleDate(events[0]["start"]) < now){
    updateCurrentEvent(events[0]);
    updateNextEvents(events.slice(1, events.length));
  }else{
    updateCurrentEvent({"name": "Available", "end": events[0]["start"]});
    updateNextEvents(events);
  }
}

function updateRoomName(roomName){
  document.getElementById("room_name").innerHTML = roomName;
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
  //seconds = (seconds < 10 ? "0" : "") + seconds;

  return hours + ":" + minutes;// + ":" + seconds;
}

function updateNextEvents(nextEvents){
  var string = "";
  nextEvents.forEach(function(event) {
    var name = event["name"];
    var start = parseGoogleDate(event["start"]);
    var end = parseGoogleDate(event["end"]);
    string = string
      + timeStringFromDateTime(start)
      + " - "
      + timeStringFromDateTime(end)
      + "<br>"
      + name
      + "<br>";
  });
  document.getElementById("next_events").innerHTML = string;
}

function updateCurrentEvent(currentEvent){
  document.getElementById("current_event").innerHTML = currentEvent["name"];
  var remainingString = "For";

  if (currentEvent["end"] == "nil"){
    remainingString = remainingString + " the rest of the day";
  } else{
    var start = new Date();
    var end = parseGoogleDate(currentEvent["end"]);
    var remaining = end - start;
    var hours = Math.floor(remaining / 3600000);
    var mins = Math.floor((remaining % 3600000) / 60000);

    if (remaining < 60000){
      remainingString = remainingString + " less than a min";
    }
    else {
      if (hours == 1){
        remainingString = remainingString + " 1 hour";
      } else if (hours > 1) {
        remainingString = remainingString + " " + hours + " hours";
      }

      if (mins == 1){
        remainingString = remainingString + " 1 min";
      } else if (mins > 1) {
        remainingString = remainingString + " " + mins + " mins";
      }
    }
  }
  remainingString = remainingString + ".";
  document.getElementById("remaining").innerHTML = remainingString;
}

function webSocketSetup(){
  function onMessage(data){
    json = JSON.parse(data);
    updateRoomName(json["room_name"]);
    updateEvents();
  }

  var protocol = location.protocol === 'https:' ? 'wss' : 'ws';

  var ws       = new WebSocket(protocol + '://' + window.location.host + window.location.pathname);
  ws.onopen    = function(){};
  ws.onclose   = function(){};
  ws.onmessage = function(message){onMessage(message.data);};

  // var sender = function(f){
  //   f.onclick    = function(){
  //     ws.send(f.getAttribute("data-duration"));
  //     return false;
  //   }
  // };
  // sender(document.getElementById('button_1'))
  // sender(document.getElementById('button_2'))
  // sender(document.getElementById('button_3'))
  // sender(document.getElementById('button_4'))

}

function pageSetup(){
  webSocketSetup()

  if (screenfull.enabled) {
    document.getElementById('full-screen').addEventListener('click', () => {
      screenfull.request()
    });

    document.addEventListener(screenfull.raw.fullscreenchange, fullscreenChange);
  }
}

function fullscreenChange() {
  if(screenfull.isFullscreen) {
    document.getElementById('full-screen').style.visibility = 'hidden';
  } else {
    document.getElementById('full-screen').style.visibility = 'visible';
  }
}

function updateClock(){
  var currentTime = new Date();
  document.getElementById("clock").innerHTML = timeStringFromDateTime(currentTime);
}
