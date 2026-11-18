#property copyright "MT5 Smart Risk Manager Pro"
#property version "2.00"
#property description "Strategy Tester-only execution fixture. Never runs on a live chart."

#include "../Include/EmergencyController.mqh"

CTrade g_fixture_trade;
bool g_setup_done=false;
bool g_finished=false;
int g_failures=0;

void TestResult(const string name,const bool condition)
  {
   Print("EXECUTION_TEST ",name,condition ? " PASS" : " FAIL");
   if(!condition) g_failures++;
  }

int OnInit()
  {
   if(MQLInfoInteger(MQL_TESTER)==0)
     {
      Print("EmergencyExecutionTestEA refuses to run outside Strategy Tester");
      return INIT_FAILED;
     }
   g_fixture_trade.SetAsyncMode(false);
   g_fixture_trade.SetTypeFillingBySymbol(_Symbol);
   g_fixture_trade.SetExpertMagicNumber(990022);
   EventSetTimer(1);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  { EventKillTimer(); }

void OnTick()
  {
   if(g_setup_done || g_finished) return;
   MqlTick quote;
   if(!SymbolInfoTick(_Symbol,quote) || quote.ask<=0.0 || quote.bid<=0.0) return;
   double volume=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   if(volume<=0.0 || point<=0.0) return;
   bool buy=g_fixture_trade.Buy(volume,_Symbol);
   uint buy_code=g_fixture_trade.ResultRetcode();
   bool sell=g_fixture_trade.Sell(volume,_Symbol);
   uint sell_code=g_fixture_trade.ResultRetcode();
   TestResult("fixture BUY opened",buy && buy_code==TRADE_RETCODE_DONE);
   TestResult("fixture SELL opened",sell && sell_code==TRADE_RETCODE_DONE);

   int stops=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double limit_price=NormalizeDouble(quote.bid-(double)MathMax(stops+10,1000)*point,_Digits);
   bool pending=g_fixture_trade.BuyLimit(volume,limit_price,_Symbol);
   uint pending_code=g_fixture_trade.ResultRetcode();
   TestResult("fixture pending order placed",
              pending && (pending_code==TRADE_RETCODE_PLACED ||
                          pending_code==TRADE_RETCODE_DONE) && OrdersTotal()>0);
   PrintFormat("EXECUTION_TEST setup positions=%d pending=%d account_mode=%d",
               PositionsTotal(),OrdersTotal(),
               (int)AccountInfoInteger(ACCOUNT_MARGIN_MODE));
   g_setup_done=true;
  }

void OnTimer()
  {
   if(!g_setup_done || g_finished) return;
   bool exhausted=false,had_failure=false;
   bool complete=SRMPProcessEmergency(g_fixture_trade,5,1,100,
                                      exhausted,had_failure);
   if(complete)
     {
      TestResult("all account positions closed",PositionsTotal()==0);
      TestResult("all pending orders canceled",OrdersTotal()==0);
      g_finished=true;
      PrintFormat("EXECUTION_TEST SUMMARY failures=%d",g_failures);
     }
   else if(exhausted)
     {
      TestResult("retry limit not exhausted",false);
      g_finished=true;
      PrintFormat("EXECUTION_TEST SUMMARY failures=%d",g_failures);
     }
  }

double OnTester()
  {
   if(!g_finished) g_failures++;
   PrintFormat("EXECUTION_TEST FINAL failures=%d finished=%d",g_failures,(int)g_finished);
   return (double)g_failures;
  }
