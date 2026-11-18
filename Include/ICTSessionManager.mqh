#ifndef SRMP_ICT_SESSION_MANAGER_MQH
#define SRMP_ICT_SESSION_MANAGER_MQH

// UTC rule for US Eastern time since 2007. Intended for current-session
// context; broker historical offsets and market holidays are separate inputs.
datetime ICTSessionUTC(const int tester_broker_utc_offset_minutes)
  {
   if(!MQLInfoInteger(MQL_TESTER)) return TimeGMT();
   // TimeGMT equals simulated broker time in Tester. Never assume it is UTC.
   if(tester_broker_utc_offset_minutes==9999) return 0;
   return TimeCurrent()-tester_broker_utc_offset_minutes*60;
  }

int ICTFirstSunday(const int year,const int month)
  {
   MqlDateTime date;
   ZeroMemory(date);
   date.year=year; date.mon=month; date.day=1;
   TimeToStruct(StructToTime(date),date);
   return 1+(7-date.day_of_week)%7;
  }

bool ICTNewYorkDST(const datetime utc)
  {
   MqlDateTime date;
   TimeToStruct(utc,date);
   MqlDateTime boundary;
   ZeroMemory(boundary);
   boundary.year=date.year;
   boundary.mon=3;
   boundary.day=ICTFirstSunday(date.year,3)+7;
   boundary.hour=7; // 02:00 EST
   datetime begins=StructToTime(boundary);
   boundary.mon=11;
   boundary.day=ICTFirstSunday(date.year,11);
   boundary.hour=6; // 02:00 EDT
   datetime ends=StructToTime(boundary);
   return utc>=begins && utc<ends;
  }

string ICTNewYorkSession(const datetime utc,bool &kill_zone)
  {
   kill_zone=false;
   if(utc<=0) return "Unknown";
   datetime ny=utc-(ICTNewYorkDST(utc) ? 4*3600 : 5*3600);
   MqlDateTime date;
   TimeToStruct(ny,date);
   int minute=date.hour*60+date.min;
   if(date.day_of_week==0 || date.day_of_week==6) return "Weekend";
   if(minute>=120 && minute<300)
     { kill_zone=true; return "London kill zone"; }
   if(minute>=420 && minute<600)
     { kill_zone=true; return "New York AM kill zone"; }
   if(minute>=810 && minute<960)
     { kill_zone=true; return "New York PM kill zone"; }
   if(minute>=0 && minute<420) return "London/Asia transition";
   if(minute>=600 && minute<810) return "New York midday";
   if(minute>=960 && minute<1200) return "London close/NY late";
   return "Asia";
  }

#endif
