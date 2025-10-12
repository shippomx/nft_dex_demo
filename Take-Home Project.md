# Project: Simple NFT Marketplace with AMM

Build a basic NFT marketplace where an automated market maker (bonding curve) automatically prices NFTs. Users can buy from and sell to a liquidity pool.

#### Attention: 

Yes, Feel free to use AI tools (such as Claude/Cursor/Windsurf/...) or open-source solidity code to expedite your progress. But you must understand what you are doing.  

------

### Core Requirements - Smart Contracts

**1. NFT Collection Contract**

- Standard ERC-721
- Pre-mint 20 NFTs to the marketplace contract upon deployment
- Simple metadata (token ID as name)

**2. AMM Marketplace Contract**

**Single Pool with Bonding Curve:**

- Pool holds ETH and NFTs
- Price automatically adjusts based on reserves
- Use simple linear bonding curve: `price = ETH_reserve / NFT_reserve`

**Key Functions:**

solidity

```solidity
// Trading
- buyNFT() payable          // Buy 1 NFT at current price
- sellNFT(uint256 tokenId)  // Sell 1 NFT back to pool

// View Functions  
- getCurrentPrice()          // Current buy price
- getSellPrice()            // Current sell price
- getPoolReserves()         // (ETH balance, NFT count)
```

**Pricing Logic:**

```
Initial State: 10 ETH + 20 NFTs
Current Price = 10 / 20 = 0.5 ETH per NFT

User buys 1 NFT:
- User pays 0.5 ETH
- Pool now has: 10.5 ETH + 19 NFTs
- New price = 10.5 / 19 = 0.553 ETH

User sells 1 NFT:
- User receives current sell price (~0.5 ETH)
- Pool now has: 10 ETH + 20 NFTs again
- Price returns to 0.5 ETH
```

**Specific Requirements:**

- 2% fee on each trade (stays in pool)
- Slippage protection (max 5%)
- Reentrancy guard
- Proper access control

**3. Testing:**

- **Minimum 5 tests:**
  - Buy NFT (price calculation)
  - Sell NFT (receive correct amount)
  - Multiple trades (price updates correctly)
  - Edge case: try to buy when pool empty
  - Fee calculation

------

### Core Requirements - Frontend Interface

**Single Page Application:**

**Display:**

- Current NFT price
- Pool reserves (X ETH, Y NFTs available)
- Your wallet (ETH balance, owned NFTs)
- Price chart showing last 10 trades (simple line chart)

**Actions:**

- Connect wallet button
- **Buy Section:**
  - "Buy 1 NFT for X ETH" button
  - Show price impact
- **Sell Section:**
  - Display your NFTs
  - Select NFT to sell
  - "Sell for X ETH" button
  - Show expected return

**Features:**

- Transaction pending/success/error states
- Auto-refresh after transactions
- Show transaction hash with etherscan link

------

### **Deliverables**

1. **GitHub Repository with:**
   - `contracts/` - Solidity contracts
   - `test/` - Test files
   - `frontend/` - React app
   - `README.md` - Setup instructions
   - `.env.example`

2. **Frontend:**

   - **React / Next.js**
   - ethers.js or wagmi

3. **Contracts:**

   - Solidity 0.8.20+
   - Hardhat or Foundry
   - OpenZeppelin contracts

   - Contracts on Sepolia (or Polygon Mumbai)
   - Include contract addresses in README
   - Funded pool with initial liquidity

4. **Documentation (in README):**
   - How to run locally
   - Design decisions
   - Known limitations
   - Test results screenshot, 
   - Demo: best   a 2-3 min video, showing: buy NFT, sell NFT, price change

------

### **Simplified Scope**

**You should focus on:**

✅ **Core AMM mechanics** - price updates with trades
✅ **Functioning contract code** - readable, secure, tested
✅ **Working frontend** - doesn't need to be pretty, just functional
✅ **Good documentation**

❌ **Do NOT waste your time on:** Liquidity provision, LP tokens, staking, or any complex UI

------

### **Bonus (Optional - Only if you have extra time)**

- Transaction history table

