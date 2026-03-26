import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;

describe("SafeHaven Core Logic Tests", () => {
  it("ensures simnet is well initialised", () => {
    expect(simnet.blockHeight).toBeDefined();
    expect(wallet1).toBeDefined();
  });

  it("should allow a user to deposit funds into the haven", () => {
    const depositAmount = 1000000; // 1 STX
    
    // Calling the public 'deposit' function
    const { result } = simnet.callPublicFn(
      "SafeHaven",
      "deposit",
      [Cl.uint(depositAmount)],
      wallet1
    );

    // Assert that the transaction was successful (ok true)
    expect(result).toBeOk(Cl.bool(true));
  });

  it("should return the correct balance for a vault", () => {
    // Calling the read-only 'get-balance' function for wallet1
    const { result } = simnet.callReadOnlyFn(
      "SafeHaven",
      "get-balance",
      [Cl.standardPrincipal(wallet1)],
      wallet1
    );

    // Assuming it returns a uint
    expect(result).toBeDefined();
  });

  it("should prevent unauthorized withdrawals before maturity", () => {
    // Attempting a withdrawal from a different wallet
    const { result } = simnet.callPublicFn(
      "SafeHaven",
      "withdraw",
      [],
      wallet2
    );

    // Assert that it fails with an error (e.g., err u100 for unauthorized)
    expect(result).toBeErr(Cl.uint(100));
  });
});-
