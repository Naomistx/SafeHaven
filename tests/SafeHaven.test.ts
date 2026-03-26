import { describe, expect, it } from "vitest";

const accounts = simnet.getAccounts();
const wallet1 = accounts.get("wallet_1")!;

describe("SafeHaven Contract Test Suite", () => {
  it("ensures simnet is well initialised", () => {
    // Validates that the local Stacks blockchain simulation is active
    expect(simnet.blockHeight).toBeDefined();
    expect(wallet1).toBeDefined();
  });

  it("should verify the contract is deployed and reachable", () => {
    // This assumes your contract is named 'SafeHaven' 
    // and has a read-only function like 'get-owner'
    // Replace 'get-owner' with an actual function from your .clar file
    const { result } = simnet.callReadOnlyFn("SafeHaven", "get-owner", [], wallet1);
    
    // Validates that the call doesn't throw and returns a response
    expect(result).toBeDefined();
  });
});
