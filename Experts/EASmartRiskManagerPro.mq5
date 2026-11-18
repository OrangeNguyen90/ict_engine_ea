// Migration entry point: reuse the existing account-protection controller.
// The separate calculator integration is not implemented by this wrapper yet.
// Do not run this and RiskProtectionEA as independent controllers for the same
// account: they share one account-scoped controller lock and protection state.
#include "RiskProtectionEA.mq5"
