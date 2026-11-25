#ifndef ICT_POSITION_RISK_RENDERER_MQH
#define ICT_POSITION_RISK_RENDERER_MQH
#include "ICTPositionRisk.mqh"
#include "ICTDashboardPanel.mqh"

string ICTPositionMoney(const double value,const SICTPositionRiskSnapshot &s,const bool signed_value=false)
  {
   if(!MathIsValidNumber(value)) return "Chưa xác định";
   return (signed_value && value>0.0 ? "+" : "")+DoubleToString(value,s.currency_digits)+" "+s.currency;
  }

string ICTPositionMoneyPercent(const double value,const SICTPositionRiskSnapshot &s,const bool signed_value=false)
  {
   string pct=(ICTPositionCapitalValid(s.capital) ? DoubleToString(ICTPositionPercent(value,s.capital),2)+"%" : "chưa có vốn hợp lệ");
   return ICTPositionMoney(value,s,signed_value)+" ("+pct+")";
  }

string ICTPositionRiskStatus(const SICTPositionRiskSnapshot &s,const double portfolio_limit=3.0)
  {
   if(!s.connected) return "MẤT KẾT NỐI — KIỂM TRA TÀI KHOẢN";
   if(s.selection_errors>0) return "ĐANG ĐỒNG BỘ VỊ THẾ";
   if(!ICTPositionCapitalValid(s.capital)) return "VỐN KHÔNG HỢP LỆ";
   if(s.totals.unknown_stops>0) return "RỦI RO CHƯA XÁC ĐỊNH ĐỦ";
   if(s.unknown_pending>0) return "LỆNH CHỜ THIẾU SL / ĐỊNH GIÁ";
   if(s.totals.count==0 && s.pending_count==0) return "CHƯA CÓ VỊ THẾ";
   double exposure=MathMax(s.totals.risk_money,s.totals.remaining_risk_money)+s.pending_risk_money;
   if(portfolio_limit>0.0 && ICTPositionPercent(exposure,s.capital)>portfolio_limit)
      return "VƯỢT NGÂN SÁCH RỦI RO";
   return "RỦI RO SL: "+ICTPositionMoneyPercent(s.totals.risk_money,s);
  }

string ICTPositionRiskBody(const SICTPositionRiskSnapshot &s)
  {
   string body="[TỔNG QUAN VỊ THẾ]\nPhạm vi: "+(s.symbol_filter=="" ? "Toàn tài khoản" : s.symbol_filter)+
      " | "+IntegerToString(s.totals.count)+" vị thế\n";
   body+="Vốn tính %: "+(s.capital_mode==ICT_POSITION_EQUITY ? "Equity " :
      s.capital_mode==ICT_POSITION_CONSERVATIVE ? "min(Balance, Equity) " : "Balance ")+ICTPositionMoney(s.capital,s)+"\n";
   body+="Balance "+ICTPositionMoney(s.balance,s)+" | Equity "+ICTPositionMoney(s.equity,s)+"\n";
   if(!s.connected) body+="MẤT KẾT NỐI: giá/vị thế có thể chưa cập nhật\n";
   if(s.selection_errors>0) body+="Đang đồng bộ vị thế: chưa đọc được "+IntegerToString(s.selection_errors)+" mục\n";
   body+="Lệnh chờ: "+IntegerToString(s.pending_count)+" | rủi ro đã tính "+ICTPositionMoney(s.pending_risk_money,s)+
      (s.unknown_pending>0 ? " (chưa đầy đủ; thiếu SL/định giá)" : "")+"\n";
   if(s.totals.count==0 && s.pending_count==0)
      return body+"Bảng tự cập nhật sau khi mở lệnh thủ công hoặc bằng EA.\n";
   body+=(s.totals.unknown_stops>0 || s.selection_errors>0 ? "Rủi ro SL đã tính (chưa đầy đủ): " : "Tổng rủi ro tới SL: ")+
      ICTPositionMoneyPercent(s.totals.risk_money,s)+"\n";
   if(s.totals.unknown_stops>0) body+="Chưa xác định SL: "+IntegerToString(s.totals.unknown_stops)+" vị thế; không tính thành 0%\n";
   body+=(s.totals.unknown_targets>0 || s.selection_errors>0 ? "P/L tại TP đã tính (chưa đầy đủ): " : "Tổng P/L dự kiến tại TP: ")+
      ICTPositionMoneyPercent(s.totals.target_money,s,true)+"\n";
   if(s.totals.unknown_targets>0) body+="Chưa xác định TP: "+IntegerToString(s.totals.unknown_targets)+" vị thế\n";
   body+="Lãi/lỗ thả nổi: "+ICTPositionMoneyPercent(s.totals.floating,s,true)+
      (s.totals.unknown_floating>0 || s.selection_errors>0 ? " (chưa đầy đủ)" : "")+"\n";
   body+="Thả nổi gồm swap, chưa trừ commission.\n";
   body+="Có thể giảm thêm tới SL: "+ICTPositionMoneyPercent(s.totals.remaining_risk_money,s)+
      (s.totals.unknown_stops>0 || s.totals.unknown_floating>0 || s.selection_errors>0 ? " (chưa đầy đủ)" : "")+"\n";
   body+="P/L ngày TK = deal BUY/SELL hôm nay (gồm phí) + floating hiện tại: "+
      (s.daily_valid ? ICTPositionMoneyPercent(s.daily_net,s,true) : "CHƯA XÁC ĐỊNH")+"\n";
   body+="P/L tại SL/TP tính từ giá vào thực tế.\n";
   body+="SL/TP dự kiến gồm swap, trừ phí + dự phòng "+ICTPositionMoney(s.cost_per_lot,s)+"/lot.\n";
   body+="Chỉ tính khối lượng còn mở; không cộng phần đã chốt.\n";
   for(int i=0;i<ArraySize(s.positions);i++)
     {
      SICTPositionRisk r=s.positions[i]; SICTPositionRiskInput p=r.position;
      body+="[VỊ THẾ #"+IntegerToString((long)p.ticket)+" | "+p.symbol+"]\n";
      body+=(p.direction>0 ? "BUY " : p.direction<0 ? "SELL " : "Hướng chưa rõ ")+DoubleToString(p.volume,4)+
         " lot | Vào "+DoubleToString(p.entry,p.digits)+"\n";
      if(!r.valid) { body+="Không đọc được dữ liệu/chi phí hợp lệ; rủi ro chưa xác định.\n"; continue; }
      body+="SL "+(p.stop>0.0 ? DoubleToString(p.stop,p.digits) : "CHƯA ĐẶT")+
         " | TP "+(p.target>0.0 ? DoubleToString(p.target,p.digits) : "CHƯA ĐẶT")+"\n";
      if(!r.stop_valid) body+="Rủi ro SL: CHƯA XÁC ĐỊNH"+(p.stop>0.0 ? " (broker chưa định giá được)" : " (chưa có SL)")+"\n";
      else if(r.locked_money>0.0) body+="Khóa lời tại SL: "+ICTPositionMoneyPercent(r.locked_money,s,true)+" | rủi ro mất vốn 0%\n";
      else body+="Rủi ro tới SL: "+ICTPositionMoneyPercent(r.risk_money,s)+"\n";
      body+="P/L dự kiến tại TP: "+(r.target_valid ? ICTPositionMoneyPercent(r.net_at_target,s,true) : "CHƯA XÁC ĐỊNH")+"\n";
      body+="Lãi/lỗ thả nổi: "+(r.floating_valid ? ICTPositionMoneyPercent(r.floating,s,true) : "CHƯA XÁC ĐỊNH")+"\n";
      body+="R:R dự kiến "+(r.rr_valid ? "1:"+DoubleToString(r.rr,2) : "--")+"\n";
     }
   return body;
  }

string ICTPositionCompactMoney(const double money,const SICTPositionRiskSnapshot &s,const bool signed_value=false)
  {
   if(!MathIsValidNumber(money)) return "CHƯA XÁC ĐỊNH";
   return (ICTPositionCapitalValid(s.capital) ? DoubleToString(ICTPositionPercent(money,s.capital),2)+"% | " : "--% | ")+
      (signed_value && money>0.0 ? "+" : "")+DoubleToString(money,s.currency_digits);
  }

int ICTPositionWorstIndex(const SICTPositionRiskSnapshot &s)
  {
   int worst=-1; double largest=-1.0;
   for(int i=0;i<ArraySize(s.positions);i++)
     {
      SICTPositionRisk r=s.positions[i];
      if(!r.valid || !r.stop_valid || !r.floating_valid) return i;
      double amount=MathMax(r.risk_money,r.remaining_risk_money);
      if(amount>largest) { largest=amount; worst=i; }
     }
   return worst;
  }

string ICTPositionSummaryLabel(const int row)
  {
   switch(row)
     {
      case 0: return "Bảo vệ tự động";
      case 1: return "P/L đang mở";
      case 2: return "Rủi ro SL + chờ";
      case 3: return "Có thể giảm thêm";
      case 4: return "P/L ngày TK*";
      case 5: return "Risk ngày + chờ";
      case 6: return "Dư địa sau SL*";
      case 7: return "Margin / Equity";
      case 8: return "Balance / Equity";
      case 9: return "Vị thế / lệnh chờ";
      case 10: return "Vị thế rủi ro nhất";
      case 11: return "Trần lệnh / ngày";
     }
   return "";
  }

string ICTPositionSummaryValue(const SICTPositionRiskSnapshot &s,const int row,
                                 const double portfolio_limit,const double daily_limit,
                                 const double per_trade_limit=3.0,const bool cumulative=true)
  {
   bool incomplete=s.selection_errors>0 || s.totals.unknown_stops>0 || s.unknown_pending>0;
   switch(row)
     {
      case 0:
         if(!s.connected) return "MẤT KẾT NỐI";
         if(!s.protection_online) return "OFFLINE";
         if(s.protection_state!=0) return "ĐÃ KHÓA TÀI KHOẢN";
         if(!s.protection_armed) return "CHƯA BẬT TỰ ĐỘNG";
         return s.protection_healthy ? "ĐANG GIÁM SÁT" : "LỖI / THIẾU QUYỀN";
      case 1: return (s.selection_errors>0 || s.totals.unknown_floating>0 ? "CHƯA ĐỦ | " : "")+
         ICTPositionCompactMoney(s.totals.floating,s,true);
      case 2: return (incomplete ? "CHƯA ĐỦ | " : "")+
         ICTPositionCompactMoney(s.totals.risk_money+s.pending_risk_money,s);
      case 3: return (incomplete || s.totals.unknown_floating>0 ? "CHƯA ĐỦ | " : "")+
         ICTPositionCompactMoney(s.totals.remaining_risk_money+s.pending_risk_money,s);
      case 4: return s.daily_valid ? ICTPositionCompactMoney(s.daily_net,s,true) : "CHƯA ĐỦ LỊCH SỬ";
      case 5:
         return !s.daily_opened_valid ? "CHƯA ĐỦ SL BAN ĐẦU" :
            (s.selection_errors>0 || s.unknown_pending>0 ? "CHƯA ĐỦ | " : "")+
            ICTPositionCompactMoney(s.daily_opened_risk_money+s.pending_risk_money,s);
      case 6:
         if(daily_limit<=0.0) return "GIỚI HẠN NGÀY ĐANG TẮT";
         if(s.symbol_filter!="") return "CẦN XEM TOÀN TÀI KHOẢN";
         if(incomplete || s.totals.unknown_floating>0 || !s.daily_valid || !ICTPositionCapitalValid(s.capital) ||
            (cumulative && !s.daily_opened_valid))
            return "CHƯA XÁC ĐỊNH";
         return ICTPositionCompactMoney(MathMax(0.0,MathMin(s.capital*daily_limit/100.0+s.daily_net-
            s.totals.remaining_risk_money-s.pending_risk_money,cumulative ?
            s.capital*daily_limit/100.0-s.daily_opened_risk_money-s.pending_risk_money : DBL_MAX)),s);
      case 7: return s.margin_valid && ICTPositionCapitalValid(s.equity) ?
         DoubleToString(ICTPositionPercent(s.margin,s.equity),1)+"% | trống "+DoubleToString(s.free_margin,s.currency_digits) : "CHƯA XÁC ĐỊNH";
      case 8: return DoubleToString(s.balance,s.currency_digits)+" / "+DoubleToString(s.equity,s.currency_digits);
      case 9: return IntegerToString(s.totals.count)+" / "+IntegerToString(s.pending_count)+
         (s.symbol_filter=="" ? " | toàn TK" : " | "+s.symbol_filter);
      case 10:
        {
         int index=ICTPositionWorstIndex(s);
         if(index<0) return "--";
         SICTPositionRisk r=s.positions[index];
         return r.position.symbol+" #"+IntegerToString((long)r.position.ticket)+
            (!r.stop_valid || !r.floating_valid || !r.valid ? " | THIẾU SL / DỮ LIỆU" : " | "+
            (ICTPositionCapitalValid(s.capital) ? DoubleToString(ICTPositionPercent(MathMax(r.risk_money,r.remaining_risk_money),s.capital),2)+"%" : "--%"));
        }
      case 11: return (per_trade_limit>0.0 ? DoubleToString(per_trade_limit,2)+"%" : "TẮT")+" / "+
         (daily_limit>0.0 ? DoubleToString(daily_limit,2)+"%" : "TẮT");
     }
   return "";
  }

// 0 neutral, 1 positive, 2 warning, 3 critical. Colour always has a text label.
int ICTPositionSummarySeverity(const SICTPositionRiskSnapshot &s,const int row,
                                const double portfolio_limit,const double daily_limit,const bool cumulative=true)
  {
   bool incomplete=!s.connected || s.selection_errors>0 || !ICTPositionCapitalValid(s.capital) ||
      !MathIsValidNumber(s.totals.risk_money) || !MathIsValidNumber(s.totals.remaining_risk_money) ||
      !MathIsValidNumber(s.pending_risk_money);
   if(row==0) return (!s.connected || !s.protection_online || s.protection_state!=0 ||
      (s.protection_armed && !s.protection_healthy) ? 3 : s.protection_armed ? 1 : 2);
   if(row==1) return incomplete || s.totals.unknown_floating>0 ? 3 : s.totals.floating<0.0 ? 3 : s.totals.floating>0.0 ? 1 : 0;
   if(row==2 || row==3)
     {
      if(incomplete || s.totals.unknown_stops>0 || s.unknown_pending>0 || (row==3 && s.totals.unknown_floating>0)) return 3;
      double amount=(row==2 ? s.totals.risk_money : s.totals.remaining_risk_money)+s.pending_risk_money;
      double used=ICTPositionPercent(amount,s.capital);
      return portfolio_limit<=0.0 ? 2 : used>portfolio_limit ? 3 : used>=portfolio_limit*0.8 ? 2 : 0;
     }
   if(row==4) return incomplete || !s.daily_valid ? 3 : s.daily_net<0.0 ? 3 : s.daily_net>0.0 ? 1 : 0;
   if(row==5)
     {
      if(incomplete || !s.daily_opened_valid || s.unknown_pending>0) return cumulative ? 3 : 2;
      double spent=ICTPositionPercent(s.daily_opened_risk_money+s.pending_risk_money,s.capital);
      return spent>=daily_limit ? 3 : spent>=daily_limit*0.8 ? 2 : 0;
     }
   if(row==6)
     {
      if(incomplete || !s.daily_valid || s.totals.unknown_stops>0 || s.unknown_pending>0 || s.totals.unknown_floating>0 ||
         (cumulative && !s.daily_opened_valid)) return 3;
      if(daily_limit<=0.0 || s.symbol_filter!="") return 2;
      double room=s.capital*daily_limit/100.0+s.daily_net-s.totals.remaining_risk_money-s.pending_risk_money;
      if(cumulative) room=MathMin(room,s.capital*daily_limit/100.0-s.daily_opened_risk_money-s.pending_risk_money);
      return room<=0.0 ? 3 : room<s.capital*daily_limit/100.0*0.25 ? 2 : 0;
     }
   if(row==7) return !s.margin_valid || !ICTPositionCapitalValid(s.equity) ? 3 :
      s.margin/s.equity>=1.0/3.0 ? 3 : s.margin/s.equity>=0.20 ? 2 : 0;
   if(row==10)
     {
      int index=ICTPositionWorstIndex(s);
      if(index>=0 && (!s.positions[index].valid || !s.positions[index].stop_valid || !s.positions[index].floating_valid)) return 3;
      if(index>=0 && ICTPositionPercent(MathMax(s.positions[index].risk_money,s.positions[index].remaining_risk_money),s.capital)>3.0) return 3;
     }
   if(row==11 && (portfolio_limit<=0.0 || daily_limit<=0.0)) return 2;
   return 0;
  }

void ICTPositionSummaryText(const string name,const string value,const int x,const int y,
                              const int pixels,const int font,const color ink,const bool bold,const string tip)
  {
   TextSetFont(bold ? "Segoe UI Semibold" : "Segoe UI",-font*10,0);
   int fit=ICTPanelFit(value,pixels,font);
   string shown=fit<StringLen(value) ? StringSubstr(value,0,(int)MathMax(0,fit-2))+"…" : value;
   ICTPanelLabel(name,shown,x,y,ink,font);
   ObjectSetString(0,name,OBJPROP_FONT,bold ? "Segoe UI Semibold" : "Segoe UI");
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tip=="" ? value : tip);
  }

void ICTRenderPositionRiskPanel(const string prefix,const SICTPositionRiskSnapshot &s,
                                  const ENUM_BASE_CORNER corner,const int x,const int y,
                                  const int width,const int height,const int font,
                                  int &page,const int moved_x,const int moved_y,const bool hidden,
                                  const double portfolio_limit=3.0,const double daily_limit=6.0,
                                  const double per_trade_limit=3.0,const bool cumulative=true)
  {
   page=0; // Risk totals and alerts always share one page.
   int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS),ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   if(cw<100 || ch<70) { ObjectsDeleteAll(0,prefix); return; }
   if(ObjectFind(0,prefix+"prev")>=0) ObjectsDeleteAll(0,prefix); // Migrate the old paged panel.
   int w=(int)MathMin(MathMax(300,width),cw-8);
   bool right=corner==CORNER_RIGHT_UPPER || corner==CORNER_RIGHT_LOWER;
   bool bottom=corner==CORNER_LEFT_LOWER || corner==CORNER_RIGHT_LOWER;
   int h=(int)MathMin(MathMax(180,height),ch-4);
   int px=moved_x>=0 ? moved_x : right ? cw-x-w : x;
   int py=moved_y>=0 ? moved_y : bottom ? ch-y-h : y;
   px=(int)MathMax(0,MathMin(px,cw-w-4)); py=(int)MathMax(0,MathMin(py,ch-64));
   h=(int)MathMin(h,ch-py-2);
   if(hidden || h<115)
     {
      for(int i=ObjectsTotal(0)-1;i>=0;i--)
        { string name=ObjectName(0,i); if(StringFind(name,prefix)==0 && name!=prefix+"eye") ObjectDelete(0,name); }
      ICTPanelButton(prefix+"eye","👁","Hiện bảng rủi ro",px+10,py+10,36,28,14);
      ObjectSetString(0,prefix+"eye",OBJPROP_FONT,"Segoe UI Emoji"); return;
     }
   int size=(int)MathMax(8,MathMin(14,font)),line=0,header=0,footer=22;
   uint tw=0,th=0;
   do
     {
      TextSetFont("Segoe UI",-size*10,0);
      line=(TextGetSize("Ag",tw,th) ? (int)th+9 : size*2+6);
      header=(int)MathMax(62,line*2+14);
      if(header+12*line+footer<=h || size<=8) break;
      size--;
     }
   while(true);
   int visible=(int)MathMin(12,MathMax(1,(h-header-footer)/line));
   h=header+visible*line+footer;
   if(bottom && moved_y<0) py=(int)MathMax(0,ch-y-h);
   py=(int)MathMax(0,MathMin(py,ch-h));
   RMPanelLeft(prefix+"panel",px,py,w,h);
   ObjectSetInteger(0,prefix+"panel",OBJPROP_SELECTABLE,true);
   ObjectSetString(0,prefix+"panel",OBJPROP_TOOLTIP,"Chọn và kéo nền để di chuyển bảng rủi ro");
   RMPanelLeft(prefix+"header",px+1,py+1,w-2,header-4);
   ObjectSetInteger(0,prefix+"header",OBJPROP_BGCOLOR,C'25,40,60');
   ICTPositionSummaryText(prefix+"title","RỦI RO & LỢI NHUẬN",px+56,py+10,w-70,size,C'241,246,253',true,"");
   int status_level=ICTPositionSummarySeverity(s,2,portfolio_limit,daily_limit);
   string status=ICTPositionRiskStatus(s,portfolio_limit);
   ICTPositionSummaryText(prefix+"status",status,px+12,py+line+12,w-24,size,
      status_level==3 ? C'255,139,146' : status_level==2 ? C'255,208,112' : C'138,199,255',true,status);
   int label_width=(int)MathMin(155,MathMax(114,w*0.40));
   string detail=ICTPositionRiskBody(s);
   for(int i=0;i<12;i++)
     {
      string suffix=IntegerToString(i);
      if(i>=visible)
        { ObjectDelete(0,prefix+"band_"+suffix); ObjectDelete(0,prefix+"label_"+suffix); ObjectDelete(0,prefix+"value_"+suffix); continue; }
      int severity=ICTPositionSummarySeverity(s,i,portfolio_limit,daily_limit,cumulative);
      color bg=(i%2==0 ? C'27,34,45' : C'33,42,55');
      color ink=C'230,237,247';
      if(severity==1) { bg=C'21,58,46'; ink=C'121,239,180'; }
      if(severity==2) { bg=C'65,49,23'; ink=C'255,210,120'; }
      if(severity==3) { bg=C'70,30,39'; ink=C'255,151,157'; }
      int top=py+header+i*line;
      RMPanelLeft(prefix+"band_"+suffix,px+1,top,w-2,line);
      ObjectSetInteger(0,prefix+"band_"+suffix,OBJPROP_BGCOLOR,bg);
      ObjectSetInteger(0,prefix+"band_"+suffix,OBJPROP_COLOR,bg);
      string label=ICTPositionSummaryLabel(i),value=ICTPositionSummaryValue(s,i,portfolio_limit,daily_limit,per_trade_limit,cumulative);
      string tip=label+": "+value+"\n"+detail;
      if(i==4 || i==6) tip="* Deal BUY/SELL từ 00:00 giờ broker + toàn bộ floating hiện tại. Gồm phí deal; không phải drawdown Equity từ đầu ngày.\n"+tip;
      if(i==5) tip="Tổng rủi ro SL ban đầu + dự phòng phí của deal mở hôm nay, kể cả đã chốt lời, cộng lệnh chờ. Thiếu lịch sử SL ban đầu thì chưa xác định. Gate cộng dồn: "+(cumulative ? "BẬT" : "TẮT")+".\n"+tip;
      if(i==3) tip="Ước tính có thể giảm thêm từ floating hiện tại tới SL, gồm dự phòng phí; lãi đã khóa tại SL không triệt tiêu phần lời có thể trả lại.\n"+tip;
      if(i==7) tip="Margin/Equity; cảnh báo từ 20%, nghiêm trọng từ 33,33%. Đây là ngưỡng hiển thị, không tự đóng lệnh.\n"+tip;
      if(i==11) tip="Trần tổng rủi ro đồng thời: "+DoubleToString(portfolio_limit,2)+"%; mục tiêu/lệnh có thể thấp hơn trần.\n"+tip;
      ICTPositionSummaryText(prefix+"label_"+suffix,label,px+10,top+3,label_width-14,size,C'192,207,225',i<=5,tip);
      ICTPositionSummaryText(prefix+"value_"+suffix,value,px+label_width,top+3,w-label_width-10,size,ink,i<=5 || severity>=2,tip);
     }
   string note=s.currency+" | "+(s.capital_mode==ICT_POSITION_CONSERVATIVE ? "% theo min(Bal,Eq)" :
      s.capital_mode==ICT_POSITION_EQUITY ? "% theo Equity" : "% theo Balance")+
      (visible<12 ? " | cửa sổ nhỏ: "+IntegerToString(visible)+"/12 mục" : " | rê chuột xem chi tiết");
   ICTPositionSummaryText(prefix+"note",note,px+10,py+h-footer+3,w-20,8,C'163,183,207',false,detail);
   ICTPanelButton(prefix+"eye","👁","Ẩn bảng rủi ro",px+10,py+10,34,26,13);
   ObjectSetString(0,prefix+"eye",OBJPROP_FONT,"Segoe UI Emoji");
  }
#endif
