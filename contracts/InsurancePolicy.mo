import Principal "mo:base/Principal";
import Time "mo:base/Time";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Error "mo:base/Error";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Float "mo:base/Float";
import Result "mo:base/Result";
import Random "mo:base/Random";

actor InsurancePolicy {
  
  // Types
  type PolicyId = Text;
  type ClaimId = Text;
  
  type PolicyType = {
    #ExchangeHack;
    #SmartContractFailure;
    #WalletCompromise;
    #StableCoinDepeg;
  };
  
  type PolicyStatus = {
    #Active;
    #Expired;
    #Claimed;
    #Canceled;
  };
  
  type ClaimStatus = {
    #Pending;
    #Approved;
    #Rejected;
    #Paid;
  };
  
  type Policy = {
    id: PolicyId;
    policyType: PolicyType;
    owner: Principal;
    coverage: Nat;
    premium: Nat;
    startTime: Time.Time;
    endTime: Time.Time;
    status: PolicyStatus;
  };
  
  type Claim = {
    id: ClaimId;
    policyId: PolicyId;
    owner: Principal;
    amount: Nat;
    evidence: Text;
    timestamp: Time.Time;
    status: ClaimStatus;
    resolutionNotes: ?Text;
  };
  
  type PolicyDetails = {
    id: PolicyId;
    policyType: PolicyType;
    owner: Principal;
    coverage: Nat;
    premium: Nat;
    startTime: Int;
    endTime: Int;
    status: PolicyStatus;
    remainingDays: Int;
  };
  
  type ClaimDetails = {
    id: ClaimId;
    policyId: PolicyId;
    owner: Principal;
    amount: Nat;
    evidence: Text;
    timestamp: Int;
    status: ClaimStatus;
    resolutionNotes: ?Text;
  };
  
  // State
  private stable var policiesEntries : [(PolicyId, Policy)] = [];
  private var policies = HashMap.HashMap<PolicyId, Policy>(0, Text.equal, Text.hash);
  
  private stable var claimsEntries : [(ClaimId, Claim)] = [];
  private var claims = HashMap.HashMap<ClaimId, Claim>(0, Text.equal, Text.hash);
  
  private stable var nextPolicyCounter : Nat = 1;
  private stable var nextClaimCounter : Nat = 1;
  
  // Insurance parameters
  private stable var basePremiumRate : Float = 0.05; // 5% of coverage amount per year
  private stable var minCoverage : Nat = 100_000; // Minimum coverage amount (in tokens)
  private stable var maxCoverage : Nat = 10_000_000; // Maximum coverage amount (in tokens)
  private stable var minDuration : Nat = 30; // Minimum policy duration in days
  private stable var maxDuration : Nat = 365; // Maximum policy duration in days

  // System functions
  system func preupgrade() {
    policiesEntries := Iter.toArray(policies.entries());
    claimsEntries := Iter.toArray(claims.entries());
  };

  system func postupgrade() {
    policies := HashMap.fromIter<PolicyId, Policy>(policiesEntries.vals(), 0, Text.equal, Text.hash);
    policiesEntries := [];
    
    claims := HashMap.fromIter<ClaimId, Claim>(claimsEntries.vals(), 0, Text.equal, Text.hash);
    claimsEntries := [];
  };

  // Helper functions
  private func generateId(prefix: Text, counter: Nat) : Text {
    prefix # "-" # Nat.toText(counter)
  };
  
  private func calculatePremium(coverage: Nat, durationDays: Nat, policyType: PolicyType) : Nat {
    let durationYears = Float.fromInt(durationDays) / 365.0;
    let coverageFloat = Float.fromInt(coverage);
    let basePremium = coverageFloat * basePremiumRate * durationYears;
    
    // Risk multiplier based on policy type
    let riskMultiplier = switch (policyType) {
      case (#ExchangeHack) 1.2;
      case (#SmartContractFailure) 1.5;
      case (#WalletCompromise) 1.1;
      case (#StableCoinDepeg) 2.0;
    };
    
    // Calculate final premium with risk multiplier
    let finalPremium = basePremium * riskMultiplier;
    
    return Int.abs(Float.toInt(finalPremium));
  };

  // Create a new insurance policy
  public shared(msg) func createPolicy(
    policyType: PolicyType,
    coverage: Nat,
    durationDays: Nat
  ) : async Result.Result<PolicyDetails, Text> {
    let caller = msg.caller;
    
    // Validate coverage amount
    if (coverage < minCoverage) {
      return #err("Coverage amount is below minimum requirement");
    };
    
    if (coverage > maxCoverage) {
      return #err("Coverage amount exceeds maximum limit");
    };
    
    // Validate duration
    if (durationDays < minDuration) {
      return #err("Policy duration is below minimum requirement");
    };
    
    if (durationDays > maxDuration) {
      return #err("Policy duration exceeds maximum limit");
    };
    
    // Calculate premium
    let premium = calculatePremium(coverage, durationDays, policyType);
    
    // In a real implementation, we would verify premium payment here
    
    // Generate policy ID
    let policyId = generateId("POL", nextPolicyCounter);
    nextPolicyCounter += 1;
    
    // Calculate timestamps
    let startTime = Time.now();
    let endTime = startTime + (Int.abs(durationDays) * 24 * 60 * 60 * 1000000000); // Convert days to nanoseconds
    
    // Create policy
    let newPolicy : Policy = {
      id = policyId;
      policyType = policyType;
      owner = caller;
      coverage = coverage;
      premium = premium;
      startTime = startTime;
      endTime = endTime;
      status = #Active;
    };
    
    policies.put(policyId, newPolicy);
    
    // Return policy details
    let currentTime = Time.now();
    let remainingTime = endTime - currentTime;
    let remainingDays = remainingTime / (24 * 60 * 60 * 1000000000);
    
    #ok({
      id = policyId;
      policyType = policyType;
      owner = caller;
      coverage = coverage;
      premium = premium;
      startTime = startTime;
      endTime = endTime;
      status = #Active;
      remainingDays = remainingDays;
    })
  };

  // File a claim
  public shared(msg) func fileClaim(
    policyId: PolicyId,
    amount: Nat,
    evidence: Text
  ) : async Result.Result<ClaimDetails, Text> {
    let caller = msg.caller;
    
    // Get policy
    let policy = policies.get(policyId);
    
    switch (policy) {
      case (null) {
        return #err("Policy not found");
      };
      
      case (?p) {
        // Verify policy owner
        if (Principal.notEqual(caller, p.owner)) {
          return #err("Only the policy owner can file a claim");
        };
        
        // Check if policy is active
        if (p.status != #Active) {
          return #err("Policy is not active");
        };
        
        // Check if policy has expired
        let currentTime = Time.now();
        if (currentTime > p.endTime) {
          // Update policy status to expired
          let updatedPolicy = {
            id = p.id;
            policyType = p.policyType;
            owner = p.owner;
            coverage = p.coverage;
            premium = p.premium;
            startTime = p.startTime;
            endTime = p.endTime;
            status = #Expired;
          };
          
          policies.put(policyId, updatedPolicy);
          
          return #err("Policy has expired");
        };
        
        // Validate claim amount
        if (amount > p.coverage) {
          return #err("Claim amount exceeds policy coverage");
        };
        
        // Generate claim ID
        let claimId = generateId("CLM", nextClaimCounter);
        nextClaimCounter += 1;
        
        // Create claim
        let newClaim : Claim = {
          id = claimId;
          policyId = policyId;
          owner = caller;
          amount = amount;
          evidence = evidence;
          timestamp = currentTime;
          status = #Pending;
          resolutionNotes = null;
        };
        
        claims.put(claimId, newClaim);
        
        // Update policy status
        let updatedPolicy = {
          id = p.id;
          policyType = p.policyType;
          owner = p.owner;
          coverage = p.coverage;
          premium = p.premium;
          startTime = p.startTime;
          endTime = p.endTime;
          status = #Claimed;
        };
        
        policies.put(policyId, updatedPolicy);
        
        #ok({
          id = claimId;
          policyId = policyId;
          owner = caller;
          amount = amount;
          evidence = evidence;
          timestamp = currentTime;
          status = #Pending;
          resolutionNotes = null;
        })
      };
    }
  };

  // Process a claim (admin only)
  public shared(msg) func processClaim(
    claimId: ClaimId,
    approved: Bool,
    notes: ?Text
  ) : async Result.Result<ClaimDetails, Text> {
    // In a production environment, this would verify msg.caller is an admin
    
    // Get claim
    let claim = claims.get(claimId);
    
    switch (claim) {
      case (null) {
        return #err("Claim not found");
      };
      
      case (?c) {
        // Ensure claim is pending
        if (c.status != #Pending) {
          return #err("Claim is not in pending status");
        };
        
        // Update claim status
        let newStatus = if (approved) { #Approved } else { #Rejected };
        
        let updatedClaim : Claim = {
          id = c.id;
          policyId = c.policyId;
          owner = c.owner;
          amount = c.amount;
          evidence = c.evidence;
          timestamp = c.timestamp;
          status = newStatus;
          resolutionNotes = notes;
        };
        
        claims.put(claimId, updatedClaim);
        
        // If approved, handle payment (in a real implementation)
        if (approved) {
          // This would initiate a payment to the policy owner
          // For now, we'll just update the status to paid
          let paidClaim : Claim = {
            id = c.id;
            policyId = c.policyId;
            owner = c.owner;
            amount = c.amount;
            evidence = c.evidence;
            timestamp = c.timestamp;
            status = #Paid;
            resolutionNotes = notes;
          };
          
          claims.put(claimId, paidClaim);
          
          // Also update the policy status
          let policy = policies.get(c.policyId);
          switch (policy) {
            case (?p) {
              let updatedPolicy = {
                id = p.id;
                policyType = p.policyType;
                owner = p.owner;
                coverage = p.coverage;
                premium = p.premium;
                startTime = p.startTime;
                endTime = p.endTime;
                status = #Claimed;
              };
              
              policies.put(c.policyId, updatedPolicy);
            };
            case (null) {}; // Should never happen
          };
          
          #ok({
            id = c.id;
            policyId = c.policyId;
            owner = c.owner;
            amount = c.amount;
            evidence = c.evidence;
            timestamp = c.timestamp;
            status = #Paid;
            resolutionNotes = notes;
          })
        } else {
          // If rejected, update the policy status back to active
          let policy = policies.get(c.policyId);
          switch (policy) {
            case (?p) {
              let updatedPolicy = {
                id = p.id;
                policyType = p.policyType;
                owner = p.owner;
                coverage = p.coverage;
                premium = p.premium;
                startTime = p.startTime;
                endTime = p.endTime;
                status = #Active;
              };
              
              policies.put(c.policyId, updatedPolicy);
            };
            case (null) {}; // Should never happen
          };
          
          #ok({
            id = c.id;
            policyId = c.policyId;
            owner = c.owner;
            amount = c.amount;
            evidence = c.evidence;
            timestamp = c.timestamp;
            status = #Rejected;
            resolutionNotes = notes;
          })
        }
      };
    }
  };

  // Get policy details
  public query func getPolicy(policyId: PolicyId) : async ?PolicyDetails {
    let policy = policies.get(policyId);
    
    switch (policy) {
      case (null) {
        return null;
      };
      
      case (?p) {
        let currentTime = Time.now();
        let remainingTime = p.endTime - currentTime;
        let remainingDays = if (remainingTime > 0) {
          remainingTime / (24 * 60 * 60 * 1000000000)
        } else {
          0
        };
        
        return ?{
          id = p.id;
          policyType = p.policyType;
          owner = p.owner;
          coverage = p.coverage;
          premium = p.premium;
          startTime = p.startTime;
          endTime = p.endTime;
          status = p.status;
          remainingDays = remainingDays;
        };
      };
    }
  };

  // Get user policies
  public query func getUserPolicies(user: Principal) : async [PolicyDetails] {
    let userPolicies = Array.filter<(PolicyId, Policy)>(
      Iter.toArray(policies.entries()),
      func((_, policy)) : Bool {
        Principal.equal(policy.owner, user)
      }
    );
    
    let currentTime = Time.now();
    
    let policyDetails = Array.map<(PolicyId, Policy), PolicyDetails>(
      userPolicies,
      func((_, policy)) : PolicyDetails {
        let remainingTime = policy.endTime - currentTime;
        let remainingDays = if (remainingTime > 0) {
          remainingTime / (24 * 60 * 60 * 1000000000)
        } else {
          0
        };
        
        {
          id = policy.id;
          policyType = policy.policyType;
          owner = policy.owner;
          coverage = policy.coverage;
          premium = policy.premium;
          startTime = policy.startTime;
          endTime = policy.endTime;
          status = policy.status;
          remainingDays = remainingDays;
        }
      }
    );
    
    return policyDetails;
  };

  // Get claim details
  public query func getClaim(claimId: ClaimId) : async ?ClaimDetails {
    let claim = claims.get(claimId);
    
    switch (claim) {
      case (null) {
        return null;
      };
      
      case (?c) {
        return ?{
          id = c.id;
          policyId = c.policyId;
          owner = c.owner;
          amount = c.amount;
          evidence = c.evidence;
          timestamp = c.timestamp;
          status = c.status;
          resolutionNotes = c.resolutionNotes;
        };
      };
    }
  };

  // Get claims for a policy
  public query func getPolicyClaims(policyId: PolicyId) : async [ClaimDetails] {
    let policyClaims = Array.filter<(ClaimId, Claim)>(
      Iter.toArray(claims.entries()),
      func((_, claim)) : Bool {
        claim.policyId == policyId
      }
    );
    
    let claimDetails = Array.map<(ClaimId, Claim), ClaimDetails>(
      policyClaims,
      func((_, claim)) : ClaimDetails {
        {
          id = claim.id;
          policyId = claim.policyId;
          owner = claim.owner;
          amount = claim.amount;
          evidence = claim.evidence;
          timestamp = claim.timestamp;
          status = claim.status;
          resolutionNotes = claim.resolutionNotes;
        }
      }
    );
    
    return claimDetails;
  };

  // Update insurance parameters (admin only)
  public shared(msg) func updateParameters(
    newBasePremiumRate: ?Float,
    newMinCoverage: ?Nat,
    newMaxCoverage: ?Nat,
    newMinDuration: ?Nat,
    newMaxDuration: ?Nat
  ) : async () {
    // In a production environment, this would verify msg.caller is an admin
    
    switch (newBasePremiumRate) {
      case (?rate) { basePremiumRate := rate };
      case (null) {};
    };
    
    switch (newMinCoverage) {
      case (?min) { minCoverage := min };
      case (null) {};
    };
    
    switch (newMaxCoverage) {
      case (?max) { maxCoverage := max };
      case (null) {};
    };
    
    switch (newMinDuration) {
      case (?min) { minDuration := min };
      case (null) {};
    };
    
    switch (newMaxDuration) {
      case (?max) { maxDuration := max };
      case (null) {};
    };
  };

  // Get insurance parameters
  public query func getParameters() : async {
    basePremiumRate: Float;
    minCoverage: Nat;
    maxCoverage: Nat;
    minDuration: Nat;
    maxDuration: Nat;
  } {
    {
      basePremiumRate = basePremiumRate;
      minCoverage = minCoverage;
      maxCoverage = maxCoverage;
      minDuration = minDuration;
      maxDuration = maxDuration;
    }
  };
} 