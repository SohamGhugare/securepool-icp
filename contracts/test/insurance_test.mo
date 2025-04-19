import Debug "mo:base/Debug";
import Principal "mo:base/Principal";

// Import the actor classes for testing
import InsurancePool "canister:InsurancePool";
import InsurancePolicy "canister:InsurancePolicy";

actor {
  public func runTests() : async Text {
    Debug.print("Running insurance platform tests...");
    
    // Test variables
    let testUser = Principal.fromText("2vxsx-fae"); // Anonymous principal for testing
    let testCoverage : Nat = 500_000;
    let testDuration : Nat = 90; // 90 days
    
    // ==================== Test InsurancePool ====================
    Debug.print("Testing InsurancePool canister...");
    
    // Test staking
    Debug.print("Testing stake function...");
    let stakeAmount : Nat = 1_000_000;
    let stakeLockPeriod : Nat = 60 * 24 * 60 * 60; // 60 days in seconds
    
    let stakeId = await InsurancePool.stake(stakeAmount, stakeLockPeriod);
    Debug.print("Stake created with ID: " # debug_show(stakeId));
    
    // Test getting stake info
    Debug.print("Testing getStake function...");
    let stakeInfo = await InsurancePool.getStake(stakeId);
    
    switch (stakeInfo) {
      case (null) {
        Debug.print("Error: Stake not found");
        return "Test failed: Stake not found";
      };
      case (?info) {
        Debug.print("Stake info: " # debug_show(info));
      };
    };
    
    // Test pool stats
    Debug.print("Testing getPoolStats function...");
    let poolStats = await InsurancePool.getPoolStats();
    Debug.print("Pool stats: " # debug_show(poolStats));
    
    // ==================== Test InsurancePolicy ====================
    Debug.print("Testing InsurancePolicy canister...");
    
    // Test creating a policy
    Debug.print("Testing createPolicy function...");
    let policyResult = await InsurancePolicy.createPolicy(#ExchangeHack, testCoverage, testDuration);
    
    var policyId = "";
    
    switch (policyResult) {
      case (#err(e)) {
        Debug.print("Error creating policy: " # e);
        return "Test failed: Could not create policy";
      };
      case (#ok(policyDetails)) {
        policyId := policyDetails.id;
        Debug.print("Policy created with ID: " # policyId);
        Debug.print("Policy premium: " # debug_show(policyDetails.premium));
      };
    };
    
    // Test getting policy details
    Debug.print("Testing getPolicy function...");
    let policyInfo = await InsurancePolicy.getPolicy(policyId);
    
    switch (policyInfo) {
      case (null) {
        Debug.print("Error: Policy not found");
        return "Test failed: Policy not found";
      };
      case (?info) {
        Debug.print("Policy info: " # debug_show(info));
      };
    };
    
    // Test filing a claim
    Debug.print("Testing fileClaim function...");
    let claimResult = await InsurancePolicy.fileClaim(
      policyId,
      testCoverage / 2, // Claim half the coverage
      "Exchange XYZ was hacked and user funds were stolen. Transaction hash: 0x1234..."
    );
    
    var claimId = "";
    
    switch (claimResult) {
      case (#err(e)) {
        Debug.print("Error filing claim: " # e);
        return "Test failed: Could not file claim";
      };
      case (#ok(claimDetails)) {
        claimId := claimDetails.id;
        Debug.print("Claim filed with ID: " # claimId);
      };
    };
    
    // Test getting claim details
    Debug.print("Testing getClaim function...");
    let claimInfo = await InsurancePolicy.getClaim(claimId);
    
    switch (claimInfo) {
      case (null) {
        Debug.print("Error: Claim not found");
        return "Test failed: Claim not found";
      };
      case (?info) {
        Debug.print("Claim info: " # debug_show(info));
      };
    };
    
    // Test processing a claim
    Debug.print("Testing processClaim function...");
    let processResult = await InsurancePolicy.processClaim(
      claimId,
      true, // Approve the claim
      ?("Claim verified and approved. Payment processed.")
    );
    
    switch (processResult) {
      case (#err(e)) {
        Debug.print("Error processing claim: " # e);
        return "Test failed: Could not process claim";
      };
      case (#ok(claimDetails)) {
        Debug.print("Claim processed. New status: " # debug_show(claimDetails.status));
      };
    };
    
    // All tests passed
    Debug.print("All tests completed successfully!");
    return "All tests passed";
  };
}; 