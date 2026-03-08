//
//  PactTests.swift
//  PactTests
//
//  Created by Yaw Snr Owusu on 2/24/26.
//

import XCTest
@testable import Pact

// MARK: - ApprovalLogicTests

/// Pure-Swift unit tests for the approvalsRequired computation and
/// mode-dependent approval/rejection thresholds. No Firestore dependency.
final class ApprovalLogicTests: XCTestCase {

    // MARK: - Helpers (mirror the logic in submitProof / onVoteCast)

    /// Computes approvalsRequired the same way submitProof() does.
    func approvalsRequired(mode: String, minimumRequiredVoters: Int?, eligibleVoterCount: Int) -> Int {
        switch mode {
        case "one_person":  return 1
        case "entire_team": return eligibleVoterCount
        default:            return minimumRequiredVoters ?? (eligibleVoterCount / 2 + 1)
        }
    }

    /// Mirrors the mode-dependent approval/rejection logic in onVoteCast.ts.
    func resolveVotes(mode: String, approveCount: Int, rejectCount: Int,
                      approvalsRequired: Int, eligibleVoterCount: Int) -> String? {
        let approve: Bool
        let reject: Bool
        switch mode {
        case "one_person":
            approve = approveCount >= 1
            reject  = rejectCount  >= 1
        case "entire_team":
            approve = approveCount >= eligibleVoterCount
            reject  = rejectCount  >= 1
        default:
            approve = approveCount >= approvalsRequired
            reject  = rejectCount  >= approvalsRequired
        }
        if approve { return "approved" }
        if reject  { return "rejected" }
        return nil
    }

    // MARK: - approvalsRequired: 3-person team (2 eligible)

    func test_approvalsRequired_3person_onePerson() {
        XCTAssertEqual(approvalsRequired(mode: "one_person", minimumRequiredVoters: nil, eligibleVoterCount: 2), 1)
    }

    func test_approvalsRequired_3person_majority_noMinSet() {
        // floor(2/2)+1 = 2
        XCTAssertEqual(approvalsRequired(mode: "majority", minimumRequiredVoters: nil, eligibleVoterCount: 2), 2)
    }

    func test_approvalsRequired_3person_majority_minSet() {
        XCTAssertEqual(approvalsRequired(mode: "majority", minimumRequiredVoters: 1, eligibleVoterCount: 2), 1)
    }

    func test_approvalsRequired_3person_entireTeam() {
        XCTAssertEqual(approvalsRequired(mode: "entire_team", minimumRequiredVoters: nil, eligibleVoterCount: 2), 2)
    }

    // MARK: - approvalsRequired: 5-person team (4 eligible)

    func test_approvalsRequired_5person_onePerson() {
        XCTAssertEqual(approvalsRequired(mode: "one_person", minimumRequiredVoters: nil, eligibleVoterCount: 4), 1)
    }

    func test_approvalsRequired_5person_majority_noMinSet() {
        // floor(4/2)+1 = 3
        XCTAssertEqual(approvalsRequired(mode: "majority", minimumRequiredVoters: nil, eligibleVoterCount: 4), 3)
    }

    func test_approvalsRequired_5person_entireTeam() {
        XCTAssertEqual(approvalsRequired(mode: "entire_team", minimumRequiredVoters: nil, eligibleVoterCount: 4), 4)
    }

    // MARK: - Submitter excluded from eligible voter count

    func test_submitterExcluded_2PersonTeam() {
        // 2-person team: submitter excluded → 1 eligible voter
        let eligible = max(1, 2 - 1) // mirrors members.count - 1
        XCTAssertEqual(eligible, 1)
        XCTAssertEqual(approvalsRequired(mode: "majority", minimumRequiredVoters: nil, eligibleVoterCount: eligible), 1)
    }

    // MARK: - Approval triggers

    func test_onePerson_oneApprove_resolves() {
        let req = approvalsRequired(mode: "one_person", minimumRequiredVoters: nil, eligibleVoterCount: 4)
        XCTAssertEqual(resolveVotes(mode: "one_person", approveCount: 1, rejectCount: 0,
                                    approvalsRequired: req, eligibleVoterCount: 4), "approved")
    }

    func test_majority_insufficientApprove_doesNotResolve() {
        let req = approvalsRequired(mode: "majority", minimumRequiredVoters: nil, eligibleVoterCount: 4)
        XCTAssertNil(resolveVotes(mode: "majority", approveCount: 2, rejectCount: 0,
                                   approvalsRequired: req, eligibleVoterCount: 4))
    }

    func test_majority_sufficientApprove_resolves() {
        let req = approvalsRequired(mode: "majority", minimumRequiredVoters: nil, eligibleVoterCount: 4)
        XCTAssertEqual(resolveVotes(mode: "majority", approveCount: 3, rejectCount: 0,
                                    approvalsRequired: req, eligibleVoterCount: 4), "approved")
    }

    func test_entireTeam_allApprove_resolves() {
        let req = approvalsRequired(mode: "entire_team", minimumRequiredVoters: nil, eligibleVoterCount: 4)
        XCTAssertEqual(resolveVotes(mode: "entire_team", approveCount: 4, rejectCount: 0,
                                    approvalsRequired: req, eligibleVoterCount: 4), "approved")
    }

    func test_entireTeam_partialApprove_doesNotResolve() {
        let req = approvalsRequired(mode: "entire_team", minimumRequiredVoters: nil, eligibleVoterCount: 4)
        XCTAssertNil(resolveVotes(mode: "entire_team", approveCount: 3, rejectCount: 0,
                                   approvalsRequired: req, eligibleVoterCount: 4))
    }

    // MARK: - Rejection triggers

    func test_onePerson_oneReject_resolves() {
        let req = approvalsRequired(mode: "one_person", minimumRequiredVoters: nil, eligibleVoterCount: 4)
        XCTAssertEqual(resolveVotes(mode: "one_person", approveCount: 0, rejectCount: 1,
                                    approvalsRequired: req, eligibleVoterCount: 4), "rejected")
    }

    func test_majority_oneReject_doesNotResolve() {
        let req = approvalsRequired(mode: "majority", minimumRequiredVoters: nil, eligibleVoterCount: 4)
        // req = 3; 1 reject is not enough
        XCTAssertNil(resolveVotes(mode: "majority", approveCount: 0, rejectCount: 1,
                                   approvalsRequired: req, eligibleVoterCount: 4))
    }

    func test_majority_symmetricReject_resolves() {
        let req = approvalsRequired(mode: "majority", minimumRequiredVoters: nil, eligibleVoterCount: 4)
        XCTAssertEqual(resolveVotes(mode: "majority", approveCount: 0, rejectCount: req,
                                    approvalsRequired: req, eligibleVoterCount: 4), "rejected")
    }

    func test_entireTeam_oneReject_resolves() {
        // Unanimous is impossible once 1 rejects
        let req = approvalsRequired(mode: "entire_team", minimumRequiredVoters: nil, eligibleVoterCount: 4)
        XCTAssertEqual(resolveVotes(mode: "entire_team", approveCount: 0, rejectCount: 1,
                                    approvalsRequired: req, eligibleVoterCount: 4), "rejected")
    }
}

// MARK: - PactTests (boilerplate)

final class PactTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
