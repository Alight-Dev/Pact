// Pact Cloud Functions — entry point
// All functions are exported from here so firebase-functions can discover them.
//
// Deploy:  firebase deploy --only functions
// Emulate: firebase emulators:start --only functions,firestore

import { initializeApp } from "firebase-admin/app";

// Initialize Admin SDK once (no-op if already initialized)
initializeApp();

// HTTP Callables
export { createTeam }                    from "./createTeam";
export { joinTeam }                      from "./joinTeam";
export { leaveTeam }                     from "./leaveTeam";
export { addGoal, updateGoal, deleteGoal } from "./manageGoal";
export { updateTeamSettings }              from "./updateTeamSettings";
export { updateOptedInActivities }       from "./updateOptedInActivities";
export { processStreakForDate }          from "./processStreakForDate";
export { sendNudge }                     from "./sendNudge";

// Firestore Triggers
export { onForgePactAgreement }  from "./onForgePactAgreement";
export { onSubmissionCreated }   from "./onSubmissionCreated";
export { onSubmissionRetaken }   from "./onSubmissionRetaken";
export { onVoteCast }            from "./onVoteCast";

// Scheduled
export { dailyStreakProcessor }  from "./dailyStreakProcessor";
