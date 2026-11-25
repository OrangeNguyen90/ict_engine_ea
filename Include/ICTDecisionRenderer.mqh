#ifndef ICT_DECISION_RENDERER_MQH
#define ICT_DECISION_RENDERER_MQH
#include "ICTDecisionEngine.mqh"
#include "ChartAnalysisRenderer.mqh"
#include "ICTDashboardPanel.mqh"
int g_ict_dashboard_page=0;
int g_ict_dashboard_x=-1,g_ict_dashboard_y=-1;
bool g_ict_dashboard_hidden=false;

string ICTBiasLabel(const int bias)
  { return bias>0 ? "BULLISH" : (bias<0 ? "BEARISH" : "NEUTRAL / UNKNOWN"); }
string ICTPriorityLabel(const SICTDecision &d)
  { return d.priority==ICT_PRIORITY_BUY ? "BUY PRIORITY" : (d.priority==ICT_PRIORITY_SELL ? "SELL PRIORITY" : "NO TRADE"); }
string ICTEvidenceLabel(const uint mask)
  { return ICTEvidenceText(mask); }
string ICTTimeLabel(const datetime value)
  { return value>0 ? TimeToString(value,TIME_DATE|TIME_MINUTES) : "unavailable"; }
string ICTPriceLabel(const double value)
  { return value>0 && MathIsValidNumber(value) ? DoubleToString(value,_Digits) : "unavailable"; }
string ICTDashboardPrice(const double value)
  { return value>0 && MathIsValidNumber(value) ? DoubleToString(value,_Digits) : "Chưa có"; }
string ICTDashboardTime(const datetime value)
  { return value>0 ? TimeToString(value,TIME_DATE|TIME_MINUTES) : "Chưa có"; }
string ICTDashboardBias(const int bias)
  { return bias>0 ? "Tăng" : bias<0 ? "Giảm" : "Trung tính / chưa rõ"; }
string ICTDashboardPriority(const SICTDecision &d)
  { return d.priority==ICT_PRIORITY_BUY ? "ƯU TIÊN MUA" : d.priority==ICT_PRIORITY_SELL ? "ƯU TIÊN BÁN" : "KHÔNG GIAO DỊCH"; }
string ICTDashboardState(const ENUM_ICT_DECISION_STATE state)
  {
   switch(state)
     {
      case ICT_WATCH: return "Theo dõi";
      case ICT_FORMING: return "Thiết lập đang hình thành";
      case ICT_WAIT_CONFIRMATION: return "Chờ xác nhận";
      case ICT_ENTRY_READY: return "Sẵn sàng vào lệnh";
      case ICT_INVALIDATED: return "Điểm vào mất hiệu lực";
      case ICT_TRADE_ACTIVE: return "Đang có vị thế";
      case ICT_RISK_BLOCKED: return "Bị chặn bởi rủi ro";
      default: return "Không giao dịch";
     }
  }
string ICTDashboardEvidence(const uint mask)
  {
   string names[9]={"HTF","Quét thanh khoản","MSS","Dịch chuyển giá","FVG","OB","Premium / Discount","SMT","Phiên"};
   string result="";
   for(int i=0;i<9;i++)
      if((mask & (uint)(1<<i))!=0) { if(result!="") result+=", "; result+=names[i]; }
   return result=="" ? "Không có" : result;
  }
string ICTDashboardTargetName(const string name)
  {
   if(name=="Swing high") return "Đỉnh cấu trúc";
   if(name=="Swing low") return "Đáy cấu trúc";
   return name=="" ? "--" : name;
  }

// Wrap instead of silently truncating reasons. Chart resize recomputes geometry.
void ICTRenderDashboard(const string prefix,const SICTDecision &d,const string session,
                        const ENUM_BASE_CORNER corner,const int margin_x,const int margin_y,
                        const int requested_width,const int font_size,
                        const int requested_height=360,const bool show_market=true,
                        const bool show_ict=true,const bool show_plan=true,const string research_advisory="")
  {
   string title="QUYẾT ĐỊNH ICT | "+_Symbol;
   string status=ICTDashboardPriority(d)+StringFormat(" | MUA %d | BÁN %d",d.buy_score,d.sell_score);
   color status_ink=(d.priority==ICT_PRIORITY_BUY ? C'105,218,154' :
                     (d.priority==ICT_PRIORITY_SELL ? C'247,135,140' : C'250,201,91'));
   string body="[BỐI CẢNH ĐA KHUNG]\nTháng / Tuần / Ngày: "+ICTDashboardBias(d.monthly_bias)+" / "+
      ICTDashboardBias(d.weekly_bias)+" / "+ICTDashboardBias(d.daily_bias)+
      "\nHTF / Cấu trúc: "+ICTDashboardBias(d.higher_bias)+" / "+ICTDashboardBias(d.structure_bias)+"\n";
   body+=research_advisory+"[TRẠNG THÁI]\n";
   body+=(d.priority==ICT_PRIORITY_WAIT ? "Chưa có ưu tiên hành động" :
           (d.strong_signal ? "Ưu tiên mạnh" : "Ưu tiên trung bình"))+" | "+
           (d.entry_confirmed ? "Đã xác nhận điểm vào (tham khảo)" : "Chưa xác nhận điểm vào")+"\n";
   body+="Xu hướng: "+ICTDashboardBias(d.higher_bias)+" | Trạng thái: "+ICTDashboardState(d.state)+"\n";
   if(show_market) {
   body+="[THỊ TRƯỜNG]\n";
   body+="Vùng giá: "+ICTDashboardPrice(d.dealing_low)+" - "+ICTDashboardPrice(d.dealing_high)+
          " | Cân bằng "+ICTDashboardPrice(d.equilibrium)+" | "+ICTDashboardText(d.price_location)+"\n";
   body+="Phiên: "+ICTDashboardText(session)+" (giờ New York; chuyển đổi từ UTC)\n";
   }
   if(show_ict) {
   body+="[BẰNG CHỨNG ICT]\n";
   body+="Bắt buộc: "+ICTDashboardEvidence(d.required)+"\n";
   body+="MUA đã xác nhận: "+ICTDashboardEvidence(d.buy_confirmed)+"\n";
   body+="MUA còn thiếu: "+ICTDashboardEvidence(d.required & ~d.buy_confirmed)+"\n";
   body+="BÁN đã xác nhận: "+ICTDashboardEvidence(d.sell_confirmed)+"\n";
   body+="BÁN còn thiếu: "+ICTDashboardEvidence(d.required & ~d.sell_confirmed)+"\n";
   body+="Quét thanh khoản: "+ICTDashboardTime(d.sweep_time)+" | MSS: "+ICTDashboardTime(d.mss_time)+"\nFVG: "+ICTDashboardTime(d.fvg_time)+"\n";
   body+="SMT: "+(d.optional_data_notes!="" ? ICTDashboardText(d.optional_data_notes) : "Xem bằng chứng đã xác nhận theo từng hướng")+"\n";
   }
   body+="[CHI TIẾT QUYẾT ĐỊNH]\nLý do: "+ICTDashboardText(d.reason)+"\nĐiều kiện bắt buộc: "+(d.hard_filters_passed ? "Đạt" : ICTDashboardText(d.hard_filter_reason))+"\n";
   body+="Chất lượng dữ liệu: "+ICTDashboardText(d.data_quality)+"\n";
   if(d.invalidation!="") body+="Mất hiệu lực: "+ICTDashboardText(d.invalidation)+"\n";
   if(show_plan) {
   body+="[KẾ HOẠCH GIAO DỊCH]\n";
   body+="DOL: "+ICTDashboardTargetName(d.dol_name)+" "+ICTDashboardPrice(d.dol)+" | Trung điểm FVG: "+ICTDashboardPrice(d.consequent_encroachment)+"\n";
   bool ready=d.state==ICT_ENTRY_READY && d.hard_filters_passed && d.risk.valid;
   body+="Vùng vào lệnh: "+ICTDashboardPrice(d.zone_low)+" - "+ICTDashboardPrice(d.zone_high)+"\n";
   body+="Giá vào: "+(ready ? ICTDashboardPrice(d.entry) : "Chưa có")+" | SL: "+(ready ? ICTDashboardPrice(d.stop) : "Chưa có")+" | TP1: "+(ready ? ICTDashboardPrice(d.target) : "Chưa có")+"\n";
   body+="TP2: "+(ready ? ICTDashboardPrice(d.target2)+" "+ICTDashboardTargetName(d.target2_name) : "Chưa có")+"\n";
   if(ready && _Point>0) body+=StringFormat("Khoảng cách SL: %.1f điểm\n",MathAbs(d.entry-d.stop)/_Point);
   body+=(ready ? StringFormat("RR %.2f | Khối lượng %.4f | Rủi ro %.2f | Lợi nhuận %.2f %s",d.risk.rr,d.risk.volume,d.risk.risk_money,d.risk.reward_money,AccountInfoString(ACCOUNT_CURRENCY)) : "Chưa có RR / khối lượng / tiền cho đến khi điểm vào và điều kiện rủi ro đạt")+"\n";
   body+=StringFormat("Rủi ro danh mục theo SL %.2f %s | Vị thế thiếu SL %d | Vị thế cùng hướng %d\n",d.portfolio_stop_risk,AccountInfoString(ACCOUNT_CURRENCY),d.portfolio_unknown_stops,d.correlated_positions);
   }
   body+="Nến đã đóng: "+ICTDashboardTime(d.as_of)+" | Cập nhật: "+ICTDashboardTime(TimeLocal())+" giờ máy\n";
   body+="Điểm bối cảnh không phải xác suất. Chỉ tham khảo, không tự gửi lệnh.\nVùng trên biểu đồ là bối cảnh, chưa xác nhận vào lệnh.";
   body+=ICTChartLegend();
   ICTRenderPagedPanel(prefix,title,status,status_ink,body,corner,margin_x,margin_y,
      requested_width,requested_height,font_size,g_ict_dashboard_page,
      g_ict_dashboard_x,g_ict_dashboard_y,g_ict_dashboard_hidden);
  }
#endif
