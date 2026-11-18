# IRL/ERL verification — 2026-11-04

## Observed build result

MetaEditor 5 build 6295 compiled all **16** workspace MQL5 programs with
**0 errors and 0 warnings**. Final replay probe compilation also completed
cleanly after its paper-ledger reporting update. All 66 source/header/binary
files matched staged inputs/outputs by SHA-256; EX5 files are beside sources.
See [build manifest](IRL_ERL_BUILD_20261104.csv).

| Program | Evidence |
| --- | --- |
| ICTDecisionSupportEA | [log](ICTDecisionSupportEA.irl_erl.compile.log) |
| RiskCalculationService | [log](RiskCalculationService.irl_erl.compile.log) |
| SmartRiskDashboard | [log](SmartRiskDashboard.irl_erl.compile.log) |
| RiskProtectionEA | [log](RiskProtectionEA.irl_erl.compile.log) |
| TradingAdvisoryEA | [log](TradingAdvisoryEA.irl_erl.compile.log) |
| ICTRangeTests | [log](ICTRangeTests.irl_erl.compile.log) |
| ICTRangeReplayEA | [log](ICTRangeReplayEA.irl_erl.compile.log) |
| ICTDecisionTests / ICTDetectorTests | [decision log](ICTDecisionTests.irl_erl.compile.log), [detector log](ICTDetectorTests.irl_erl.compile.log) |
| EmergencyExecutionTestEA, OBSMTEmptyProbeEA, OBSMTProbeEA, Phase3ProbeEA, ProtectionPolicyTestEA, ProtectionPolicyTests, ResetProtectionState | Individual `*.irl_erl.compile.log` files; compile only |

VS Code diagnostics reported no errors. An execution-API source search found
no OrderSend/CTrade/open/close/cancel call in the new range modules, range tests,
replay probe, standalone decision EA or calculation service. The existing
emergency controller retains its close/cancel calls.

All five [protected-module source hashes](IRL_ERL_PROTECTION_BASELINE.csv) were
unchanged after implementation. This verifies source preservation, not new
Netting/Hedging or emergency runtime acceptance.

## Executed Tester attempts

Fresh [Tester/startup evidence](IRL_ERL_TESTER_20261104.log) records:

| Attempt | Local log time, UTC+7 | Actual outcome |
| --- | --- | --- |
| `ict_range.ini` → ICTRangeTests | 11:45:29.769 | tester not started because the account is not specified |
| `ict_range_EURUSD_09.ini` → ICTRangeReplayEA | 11:45:54.393 | same pre-initialization failure |

Both runs used the isolated portable terminal with trading, DLL, remote and cloud
disabled. The user's running installed terminal was not used, attached to or
reconfigured. No credentials were read/copied. The process exit is not a PASS.

**Neither test program reached initialization. No assertion result, replay,
paper fill/exit, signal count or trading performance was produced.** There is
no runtime PASS claim. Other prepared historical configurations were not run
because the same terminal account prerequisite blocks initialization.

## Core acceptance matrix

| Required behavior | Prepared coverage | Current evidence |
| --- | --- | --- |
| Confirmed structural dealing range and stable ID | Pure range fixture and existing swing detector | Compiles; runtime blocked |
| Unconfirmed swing / HTF close does not leak | Confirmation boundary, prefix replay and existing structure fixtures | Compiles; runtime blocked |
| IRL/ERL membership by owner, crossing exclusion | Range membership/foreign-owner fixtures | Compiles; runtime blocked |
| Sweep vs noise vs candidate vs breakout | Closed-level reducer fixtures | Compiles; runtime blocked |
| FVG partial/full/invalidation, OB lifecycle | Retained ICTDetectorTests plus shared pure APIs | Compiles; no fresh runtime result |
| Bullish and bearish rotation with later structure/reaction | Mirrored chronological RangeTests fixture | Compiles; runtime blocked |
| Missing data / invalid RR → no action | Missing-prefix and gross-geometry fixtures; existing net-risk calculator | Compiles; actual broker cost/margin gates unaccepted |
| Same result in EA and indicator | Shared pack/unpack, file roundtrip and seqlock refusal fixtures | Compiles; roundtrip not executed |
| No auto entry | Default false input, initialization guard and source API search | Source/build evidence only |
| Protection preserved | Five unchanged source hashes and clean regression compile | No new execution acceptance |
| Chart layers / dashboard movement and paging | Existing primitive reuse, scoped bounded renderer | Visual acceptance pending |
| Real-history / out-of-sample / forward performance | Six configs plus Tester-only paper probe | No metrics; initialization blocked |

## Replay reporting available when runnable

The paper probe logs SignalID-tagged virtual fill/exit events, technical signal
counts, pending invalidation, TP/SL hit counts, net wins/losses, mean realized R,
after-estimated-cost expectancy and modeled equity drawdown. Outputs are grouped
by the configured symbol and HTF/MTF/LTF combination. Session attribution uses
`Replay_Broker_UTC_Offset_Minutes`; unknown default `9999` reports an Unknown UTC
bucket instead of guessing broker UTC/DST. Known offsets produce London/NY
kill-zone and outside-kill-zone groups. Split replay across broker offset changes.

The paper reference starts at 10,000 account-currency units, risk 1%, cap 2%,
minimum net RR 2, round-turn unspecified-cost reserve 10 per lot, estimated
adverse slippage 2 points. These are transparent test assumptions, not optimized
broker settings. Virtual margin is checked against virtual balance too. Pending
invalidation per technical signal is not the same as trade loss rate. Open virtual
positions are disclosed and excluded from realized expectancy; equity drawdown
includes modeled floating P/L. Tester OHLC/model path is not a verified real tick
execution path or proof of achievable fills.

## Still required for acceptance

Run fixtures in a configured demo/test terminal, retain fresh assertion and Tester
completion records, then replay verified broker symbols over chronological
in-sample/holdout data and forward observe. Verify missing/stale/unsynchronized
history, revision latch, bounded-history restart, transaction-cost/spread/margin
rejections, all chart layers at several chart sizes, and protection regression
on Netting/Hedging before operational use. No live-account test was performed.

See [delivery and configuration](IRL_ERL_DELIVERY.md) for implemented boundaries,
including broker-day session alias, bounded candidates/history and lack of
crash-durable state restoration. **The attachment's final acceptance conditions
remain open.**
