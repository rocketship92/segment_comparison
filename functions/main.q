// main functions file

.segComp.leaderboard.raw:{[dict]                                                                / compare segments
  `dict2 set dict;
  dict:delete athlete_id from dict;
  empty:![([] Segment:());();0b;enlist[(`$string .return.athleteData[][`id])]!()];
  if[not max dict`following`include_clubs; :empty];
  segments:0!.return.segments.allActivities[dict];
  if[0=count segments; :empty];
  details:$[(7=type dict`club_id)&(not all null dict`club_id);
    flip[dict] cross ([] segment_id:segments`id);
    @[dict;`segment_id;:;] each segments`id
  ];
//  details:@[ @[dict;`club_id;:;(),dict`club_id] ;`segment_id;:;] each segments`id;
  .log.out"returning segment leaderboards";
  lead:.return.leaderboard.all[1b] each details;
  lead:@[raze lead where 1<count each lead;`athlete_name;`$];		      						/ return results with more than 1 entry
  `.cache.athletes upsert distinct select id:athlete_id, name:athlete_name from lead;
  .disk.saveCache[`athletes] .cache.athletes;
  .log.out"pivoting results";
  P:asc exec distinct `$string athlete_id from lead;
  res:0!exec P#((`$string athlete_id)!elapsed_time) by Segment:Segment from lead;
  cl:`Segment,`$string .return.athleteData[]`id;
  .log.out"returning raw leaderboard";
  :(cl,cols[res] except cl) xcols res;
 };

.segComp.leaderboard.hr:{[dict]
  res:.segComp.leaderboard.raw dict;
  `resRAW set res;
  ath:.return.athleteName each "J"$string 1_ cols res;
  :(`Segment,ath) xcol update .return.segmentName each Segment from res;
 };

.segComp.leaderboard.html:{[data]
  ath:.return.athleteName each "J"$string 1_ cols data;
  :(`Segment,ath) xcol update .return.html.segmentURL each Segment from data;
 };

.segComp.leaderboard.highlight:{[data]
  bb:data,'?[@[data;1_cols data;0w^];();0b;enlist[`tt]!enlist(min@\:;(enlist,1_cols data))];
  func:{$[x=y;"<mark>",string[x],"<mark>";string x]};
  :delete tt from ![bb;();0b;(1_cols data)!{((';x);y;`tt)}[func] each 1_cols data];
 };

.segComp.summary.raw:{[data]
  bb:data,'?[@[data;1_cols data;0w^];();0b;enlist[`tt]!enlist(min@\:;(enlist,1_cols data))];
  func:{x=y};
  res:delete tt from ![bb;();0b;(1_cols data)!{((';x);y;`tt)}[func] each 1_cols data];
  tab:([] Athlete:`$(); Total:(); Segments:());
  :tab upsert {segs:?[x;enlist(=;y;1);();`Segment]; (y; count segs; segs)}[res] each 1_cols res;
 };

.segComp.summary.hr:{[dict]
  res:.segComp.summary.raw .segComp.leaderboard.raw dict;
  :update .return.athleteName each "J"$string Athlete, .return.segmentName@/:/:Segments from res;
 };

.segComp.summary.html:{[data]
  res:.segComp.summary.raw data;
  :update .return.html.athleteURL each "J"$string Athlete, .return.html.segmentURL@/:/:Segments from res;
 };

.return.clean:{[dict]                                                                           / return existing parameters in correct format
  def:(!/) .var.defaults`vr`vl;                                                                 / defaults value for parameters
  :.Q.def[def] string key[def]#def,dict;                                                        / return valid optional parameters
 };

.return.params.all:{[params;dict]                                                               / build url from specified altered parameters
  if[0=count dict; :""];                                                                        / if no parametrs return empty string
  def:(!/) .var.defaults`vr`vl;                                                                 / defaults value for parameters
  n:inter[(),params] where not def~'.Q.def[def] {$[10=abs type x;x;string x]} each dict;        / return altered parameters
  :" " sv ("-d ",/:string[n],'"="),'{func:exec fc from .var.defaults where vr in x; raze func @\: y}'[n;dict n];  / return parameters
 };

.return.params.valid:{[params;dict] .return.params.all[params] .return.clean[dict]}

.return.activities:{[dict]                                                                      / return activities
  .log.out"retrieving activity list";
  if[0=count .cache.activities;
    act:.connect.pagination["activities";""];
    data:{select `long$id, name, "D"$10#start_date, commute from x} each act where not act@\:`manual;
    .log.out"retrieved ",string[count data]," activities from strava";
    `.cache.activities upsert data;
    .disk.saveCache[`activities] .cache.activities;
  ];
  res:select from .cache.activities where start_date within dict`after`before;
  .log.out"found ",string[count res]," activities in date range ",raze string dict[`after]," to ",dict[`before];
  :res;
 };

.return.activityDetail:{[id]
  :.connect.simple["activities/",string id;""];
 };

.return.segments.activity:{[n]
  .log.out"getting segment efforts for activity: ",string n;
  if[0=count s:.return.activityDetail[n][`segment_efforts]; :enlist 0N];
  rs:distinct select `long$id, name, starred from s[`segment] where not private, not hazardous;
  `.cache.segments upsert rs;                                                                   / upsert to segment cache
  .disk.saveCache[`segments] .cache.segments;
  :(),rs`id;
 };

.return.segments.allActivities:{[dict]                                                          / return segment data from activity list
  if[0=count .cache.segments;
    `.cache.segments upsert {select `long$id, name, starred from x} each .connect.simple["segments/starred";""];  / return starred segments
    .disk.saveCache[`segments] .cache.segments;
  ];
  activ:0!.return.activities[dict];
  if[0=count activ;
    .log.error"lack of activities in date range";
    :0#.cache.segments;
  ];
  incache:except[;0N] raze $[0=count .cache.segByAct;();.cache.segByAct activ`id];				/ remove processed activities
  newres:(),exec id from activ where not id in key .cache.segByAct;
  .cache.segByAct,:segs:newres!.return.segments.activity each newres;
  .disk.saveCache[`segByAct].cache.segByAct;
  ids:distinct raze incache,value segs; / exec id from .cache.segments where starred;
  .log.out"returning segments";
  res:select from .cache.segments where id in ids;
  if[0=count res; .log.error"lack of segments in date range"];
  :res;
 };

.refresh.segments.byActivity:{[id]
  segs:.return.segments.activity id;
  tab:flip `following`include_clubs`segment_id!flip 10b,/:segs;
  :.return.leaderboard.all[0b] each tab;
 };

.return.segmentName:{[id]
  if[count segName:.cache.segments[id]`name; :segName];                                         / if cached then return name
  res:.connect.simple ["segments/",string id;""]`name;                                          / else request data
  :res;
 };

.return.html.segmentURL:{[id]
  :.h.ha["http://www.strava.com/segments/",string id] .return.segmentName[id];
 };

.return.athleteName:{[id] first value .cache.athletes id};

.return.html.athleteURL:{[id]                                                                   / for use with .cache.leaderboards
  :.h.ha["http://www.strava.com/athletes/",string id] string .return.athleteName[id];
 };

.return.clubs:{[]                                                                               / return list of users clubs
  .log.out"Retrieving club data";
  .return.athleteData[];
  if[count .cache.clubs;
    .log.out"Returning cached club data";
    :.cache.clubs;
  ];
  .log.out"Returning club data from strava.com";
  `.cache.clubs upsert rs:select `long$id, name from .return.athleteData[][`clubs];
  .disk.saveCache[`clubs] .cache.clubs;
  :`id xkey rs;
 };

.return.athleteData:{[]
  if[0<count .var.athleteData; :.var.athleteData];                                              / return cached result if it exists
  .log.out"Retrieving Athlete Data from Strava.com";
  ad:.connect.simple["athlete";""];
  ad[`fullname]:`$" " sv ad[`firstname`lastname];                                               / add fullname to data
  ad:@[ad;`id;`long$];                                                                          / return athlete_id as type long
  `.var.athleteData set ad;
  :ad;
 };

.return.stream.segment:{[segId]
//  .log.out"Retrieving stream for segment: ",string[segId];
  if[0<count res:raze exec data from .cache.streams.segments where id = segId; :res];
  stream:first .connect.simple["segments/",string[segId],"/streams/latlng";""];
  data:stream`data;
  `.cache.streams.segments upsert (segId;data);
  .disk.saveCache[`seg_streams] .cache.streams.segments;
  :data;
 };

.return.stream.activity:{[actId]
  if[0<count res:raze exec data from .cache.streams.activities where id = actId; :res`data];
  aa:first .connect.simple["activities/",string[actId],"/streams/latlng";""];
  data:aa`data;
  `.cache.streams.activities upsert (actId;data);
  .disk.saveCache[`act_streams] .cache.streams.activities;
  :data;
 };

.return.leaderboard.all:{[getCache;dict]
  if[not `segment_id in key dict; .log.error"Need to specify a segment id"; :()];
  rs:([athlete_id:`long$()] athlete_name:(); elapsed_time:`minute$(); Segment:`long$());
  if[1b=dict`include_clubs;
    {.log.out"returning segment: ",x,", club_id: ",y} . string dict`segment_id`club_id;
    rs,:.return.leaderboard.sub[getCache;dict;`club_id;dict`club_id];                           / return leaderboard of followers
   ];
  if[1b=dict`following;
    .log.out"returning segment: ",string[dict`segment_id],", following";
    rs,:.return.leaderboard.sub[getCache;dict;`following;0N];                                   / return leaderboard of clubs
   ];
  :`Segment xcols 0!rs;
 };

.return.leaderboard.sub:{[getCache;dict;typ;leadId]
  if[getCache & 0<count rs:select from .cache.leaderboards where segmentId=dict`segment_id, resType=typ, resId=leadId;
    :(raze exec res from rs) cross ([] Segment:enlist dict`segment_id);
   ];
  extra:.return.params.valid[typ] dict;
  message:.connect.simple["segments/",string[dict`segment_id],"/leaderboard"] extra;
  res:$[0=count message`entries;
    raze exec res from rs;
    select `long$athlete_id, athlete_name, `minute$elapsed_time from message`entries
  ];
  `.cache.leaderboards upsert (dict`segment_id;typ;leadId;res);
  .disk.saveCache[`leaderboard] .cache.leaderboards;
  :res cross ([] Segment:enlist dict`segment_id);
 };
