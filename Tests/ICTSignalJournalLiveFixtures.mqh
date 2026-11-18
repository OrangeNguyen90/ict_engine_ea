#ifndef ICT_SIGNAL_JOURNAL_LIVE_FIXTURES_MQH
#define ICT_SIGNAL_JOURNAL_LIVE_FIXTURES_MQH

#include "../Include/ICTSignalResult.mqh"

// Caller supplies SignalFixture and Check as in ICTUnifiedCoreFixtures.mqh.
void TestICTSignalJournalLive()
  {
   SICTSignalResult committed; SICTSignalResult current;
   SignalFixture(committed); ICTEvaluateSignal(committed,2);
   SignalFixture(current); ICTEvaluateSignal(current,2); current.rr=2.5;
   ICTSignalReconcileCommittedLive(committed,current);
   Check("live matching plan uses fresh RR while journal stays immutable",
      current.confirmed && current.risk_pass && current.rr==2.5 && committed.rr==3);

   SignalFixture(current); current.risk_pass=false; ICTEvaluateSignal(current,2);
   string veto=current.reason;
   ICTSignalReconcileCommittedLive(committed,current);
   Check("risk veto remains published while journal remains confirmed",
      !current.confirmed && !current.risk_pass && current.reason==veto && committed.confirmed);

   SignalFixture(current); ICTEvaluateSignal(current,2); current.entry=101;
   ICTSignalReconcileCommittedLive(committed,current);
   Check("changed live plan cannot publish historical confirmation",
      !current.confirmed && !current.risk_pass && current.state==ICT_SIGNAL_NO_TRADE && committed.entry==100);

   SignalFixture(current); ICTEvaluateSignal(current,2); current.target_pool_id="DIFFERENT_POOL";
   ICTSignalReconcileCommittedLive(committed,current);
   Check("changed target identity cannot reuse committed confirmation",!current.confirmed && committed.confirmed);

   SignalFixture(current); ICTEvaluateSignal(current,2); current.risk_pass=false;
   ICTSignalReconcileCommittedLive(committed,current);
   Check("inconsistent confirmed flags fail closed",!current.confirmed && !current.risk_pass);

   SignalFixture(current,-1); ICTEvaluateSignal(current,2);
   ICTSignalReconcileCommittedLive(committed,current);
   Check("opposite live confirmation cannot replace committed signal",!current.confirmed && committed.direction==1);
  }
#endif
