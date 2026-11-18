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

string ICTPositionRiskStatus(const SICTPositionRiskSnapshot &s)
  {
   if(s.selection_errors>0) return "ĐANG ĐỒNG BỘ VỊ THẾ";
   if(s.totals.count==0) return "CHƯA CÓ VỊ THẾ";
   if(s.totals.unknown_stops>0) return "RỦI RO CHƯA XÁC ĐỊNH ĐỦ";
   return "RỦI RO SL: "+ICTPositionMoneyPercent(s.totals.risk_money,s);
  }

string ICTPositionRiskBody(const SICTPositionRiskSnapshot &s)
  {
   string body="[TỔNG QUAN VỊ THẾ]\nPhạm vi: "+(s.symbol_filter=="" ? "Toàn tài khoản" : s.symbol_filter)+
      " | "+IntegerToString(s.totals.count)+" vị thế\n";
   body+="Vốn tính %: "+(s.capital_mode==ICT_POSITION_EQUITY ? "Equity " : "Balance ")+ICTPositionMoney(s.capital,s)+"\n";
   body+="Balance "+ICTPositionMoney(s.balance,s)+" | Equity "+ICTPositionMoney(s.equity,s)+"\n";
   if(!s.connected) body+="MẤT KẾT NỐI: giá/vị thế có thể chưa cập nhật\n";
   if(s.selection_errors>0) body+="Đang đồng bộ vị thế: chưa đọc được "+IntegerToString(s.selection_errors)+" mục\n";
   if(s.totals.count==0)
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

void ICTRenderPositionRiskPanel(const string prefix,const SICTPositionRiskSnapshot &s,
                                  const ENUM_BASE_CORNER corner,const int x,const int y,
                                  const int width,const int height,const int font,
                                  int &page,const int moved_x,const int moved_y,const bool hidden)
  {
   color ink=(s.selection_errors>0 || s.totals.unknown_stops>0 ? clrTomato : clrGold);
   ICTRenderPagedPanel(prefix,"RỦI RO & LỢI NHUẬN",ICTPositionRiskStatus(s),ink,ICTPositionRiskBody(s),
      corner,x,y,width,height,font,page,moved_x,moved_y,hidden,1);
  }
#endif
