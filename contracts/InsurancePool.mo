import Principal "mo:base/Principal";
import Time "mo:base/Time";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Option "mo:base/Option";
import Error "mo:base/Error";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Hash "mo:base/Hash";
import Result "mo:base/Result";

actor InsurancePool {
  
  // Types
  type StakeId = Nat;
  type Stake = {
    id: StakeId;
    owner: Principal;
    amount: Nat;
    timestamp: Time.Time;
    lockPeriod: Nat; // in seconds
    apy: Float;
  };

  type StakeInfo = {
    id: StakeId;
    owner: Principal;
    amount: Nat;
    timestamp: Int;
    lockPeriod: Nat;
    apy: Float;
    rewards: Float;
    maturityDate: Int;
  };

  // State
  private stable var nextStakeId : StakeId = 0;
  private stable var poolLiquidity : Nat = 0;
  private stable var totalStaked : Nat = 0;
  private stable var defaultApy : Float = 5.0; // 5% APY
  
  // Stake entries - persisted via upgrades
  private stable var stakeEntries : [(StakeId, Stake)] = [];
  private var stakes = HashMap.HashMap<StakeId, Stake>(0, Nat.equal, Hash.hash);

  // Initialize after upgrade
  system func preupgrade() {
    stakeEntries := Iter.toArray(stakes.entries());
  };

  system func postupgrade() {
    stakes := HashMap.fromIter<StakeId, Stake>(stakeEntries.vals(), 0, Nat.equal, Hash.hash);
    stakeEntries := [];
  };

  // Stake tokens into the pool
  public shared(msg) func stake(amount: Nat, lockPeriod: Nat) : async StakeId {
    let caller = msg.caller;
    
    // Ensure amount is greater than 0
    if (amount == 0) {
      throw Error.reject("Cannot stake 0 tokens");
    }
    
    // In a real implementation, we would transfer tokens from the caller to the contract
    // For simplicity, we're just updating our internal state
    
    let stakeId = nextStakeId;
    nextStakeId += 1;
    
    // Calculate APY based on lock period (longer periods get better APY)
    let apy = calculateApy(lockPeriod);
    
    let newStake : Stake = {
      id = stakeId;
      owner = caller;
      amount = amount;
      timestamp = Time.now();
      lockPeriod = lockPeriod;
      apy = apy;
    };
    
    stakes.put(stakeId, newStake);
    poolLiquidity += amount;
    totalStaked += amount;
    
    return stakeId;
  };

  // Calculate APY based on lock period
  private func calculateApy(lockPeriod: Nat) : Float {
    // Base APY
    let baseApy = defaultApy;
    
    // Bonus APY for longer lock periods
    // 30 days = 2.5M seconds
    if (lockPeriod >= 7776000) { // 90 days
      return baseApy + 5.0; // +5% for 90+ days
    } else if (lockPeriod >= 5184000) { // 60 days
      return baseApy + 3.0; // +3% for 60+ days
    } else if (lockPeriod >= 2592000) { // 30 days
      return baseApy + 1.0; // +1% for 30+ days
    } else {
      return baseApy;
    }
  };

  // Unstake tokens from the pool
  public shared(msg) func unstake(stakeId: StakeId) : async Result.Result<Nat, Text> {
    let caller = msg.caller;
    
    // Get the stake
    let stake = stakes.get(stakeId);
    
    switch (stake) {
      case (null) {
        return #err("Stake not found");
      };
      
      case (?s) {
        // Check if caller is the stake owner
        if (Principal.notEqual(caller, s.owner)) {
          return #err("Only the stake owner can unstake");
        };
        
        let currentTime = Time.now();
        let elapsedTime = currentTime - s.timestamp;
        
        // Check if lock period has ended
        if (elapsedTime < s.lockPeriod * 1000000000) { // Convert seconds to nanoseconds
          return #err("Lock period has not ended");
        };
        
        // Calculate rewards
        let elapsedTimeInYears = Float.fromInt(elapsedTime) / 31536000000000000.0; // nanoseconds in a year
        let rewardRate = s.apy / 100.0;
        let rewards = Float.fromInt(s.amount) * rewardRate * elapsedTimeInYears;
        let totalAmount = s.amount + Int.abs(Float.toInt(rewards));
        
        // Update pool liquidity
        if (poolLiquidity >= totalAmount) {
          poolLiquidity -= totalAmount;
          totalStaked -= s.amount;
        } else {
          return #err("Insufficient pool liquidity");
        };
        
        // Remove stake
        stakes.delete(stakeId);
        
        // In a real implementation, we would transfer tokens back to the caller
        
        return #ok(totalAmount);
      };
    }
  };

  // Get stake information
  public query func getStake(stakeId: StakeId) : async ?StakeInfo {
    let stake = stakes.get(stakeId);
    
    switch (stake) {
      case (null) {
        return null;
      };
      
      case (?s) {
        let currentTime = Time.now();
        let elapsedTime = currentTime - s.timestamp;
        let elapsedTimeInYears = Float.fromInt(elapsedTime) / 31536000000000000.0; // nanoseconds in a year
        let rewardRate = s.apy / 100.0;
        let rewards = Float.fromInt(s.amount) * rewardRate * elapsedTimeInYears;
        let maturityTimestamp = s.timestamp + (s.lockPeriod * 1000000000);
        
        return ?{
          id = s.id;
          owner = s.owner;
          amount = s.amount;
          timestamp = s.timestamp;
          lockPeriod = s.lockPeriod;
          apy = s.apy;
          rewards = rewards;
          maturityDate = maturityTimestamp;
        };
      };
    }
  };

  // Get all stakes for a user
  public query func getUserStakes(user: Principal) : async [StakeInfo] {
    let userStakes = Array.filter<(StakeId, Stake)>(
      Iter.toArray(stakes.entries()),
      func((_, stake)) : Bool {
        Principal.equal(stake.owner, user)
      }
    );
    
    let stakeInfos = Array.map<(StakeId, Stake), StakeInfo>(
      userStakes,
      func((_, stake)) : StakeInfo {
        let currentTime = Time.now();
        let elapsedTime = currentTime - stake.timestamp;
        let elapsedTimeInYears = Float.fromInt(elapsedTime) / 31536000000000000.0;
        let rewardRate = stake.apy / 100.0;
        let rewards = Float.fromInt(stake.amount) * rewardRate * elapsedTimeInYears;
        let maturityTimestamp = stake.timestamp + (stake.lockPeriod * 1000000000);
        
        {
          id = stake.id;
          owner = stake.owner;
          amount = stake.amount;
          timestamp = stake.timestamp;
          lockPeriod = stake.lockPeriod;
          apy = stake.apy;
          rewards = rewards;
          maturityDate = maturityTimestamp;
        }
      }
    );
    
    return stakeInfos;
  };

  // Get pool statistics
  public query func getPoolStats() : async {
    liquidity: Nat;
    totalStaked: Nat;
    stakersCount: Nat;
    baseApy: Float;
  } {
    let uniqueStakers = HashMap.HashMap<Principal, Bool>(0, Principal.equal, Principal.hash);
    
    for ((_, stake) in stakes.entries()) {
      uniqueStakers.put(stake.owner, true);
    };
    
    {
      liquidity = poolLiquidity;
      totalStaked = totalStaked;
      stakersCount = uniqueStakers.size();
      baseApy = defaultApy;
    }
  };

  // Update pool's base APY (only for admin, should be restricted)
  public shared(msg) func updateBaseApy(newApy: Float) : async () {
    // In a production environment, this would check if msg.caller is an admin
    defaultApy := newApy;
  };
} 