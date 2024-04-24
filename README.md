# Token Beamer

Solidity smart contract for transferring multiple asset types (native currency,
ERC-20, -721, -1155) to multiple recipients within one transaction, and checking
approval states of different tokens with a single call.

## To do before handing off for audit

- [x] Hardhat environment setup and config
- [x] Contract code polish and peer review
- [x] Deploy script
- [x] Add license
- [x] Add Readme
- [x] Create repository
- [x] Invite user `qs-scope-2024` to Github repo
- [ ] Unit tests (+ docs on how to run them)
- [ ] Submit
      [Quantstamp audit form](https://audit.quantstamp.com/new?from=e249c66d5786374)

## Developer guide

### Deploy and verify

- install and run pnpm to fetch dependencies
- set up your environment: copy `.env.example` to `.env` and add your mnemonic
- deploy contract (e.g. to Beam network):

```bash
npx hardhat --network beam deploy --tags TokenBeamer
```

- verify contract:

```bash
# verify on Sourcify:
npx hardhat --network beam sourcify

# verify on Etherscan & Co on supported networks:
npx hardhat --network ethereum etherscan-verify
```

### Admin functionality

- use `setTipRecipient(newRecipient)` to change the tip recipient address
- use `disableUpgrades()`to **permanently** disable the upgradeability of the
  smart contract
- use `recoverFunds(to, token, type_, id, value)` to transfer funds stuck in the
  contract

### Unit tests

_TODO: when done, write docs on how to run them_

## User guide

The following examples use _viem_, please refer to the
[viem docs](https://viem.sh/docs/contract/getContract) on how to instantiate
your TokenBeamer contract instance.

### Multi-transfer Tokens

TokenBeamer can be used to transfer native currency, different ERC-20 tokens,
and ERC-721 and 1155 NFTs to one or multiple recipients within one transaction.
The owner needs to **approve all tokens** to the TokenBeamer contract first.

- Send **ERC20 tokens** (18 decimals) - 600 $AAA to Alice, 400 $BBB to Bob:

```javascript
await contract.write.beamTokens([
  // recipients
  [
    "0x00000000000000000000000000000000000a71CE",
    "0x0000000000000000000000000000000000000B0b",
  ],
  // token contract addresses
  [
    "0xAAA0000000000000000000000000000000000AAA",
    "0xBBB0000000000000000000000000000000000BBB",
  ],
  [20n, 20n], // use type `20` for ERC-20
  [0n, 0n], // use token id 0
  [parseEther("600"), parseEther("400")], // values to transfer
]);
```

- Send 600 units of **native currency** (e.g. ETH) to Alice, and 400 to Bob:

```javascript
await contract.write.beamTokens(
  [
    // recipients
    [
      "0x00000000000000000000000000000000000a71CE",
      "0x0000000000000000000000000000000000000B0b",
    ],
    // use zero-address for native currency
    [
      "0x0000000000000000000000000000000000000000",
      "0x0000000000000000000000000000000000000000",
    ],
    [0n, 0n], // use type 0
    [0n, 0n], // use token id 0
    [parseEther("600"), parseEther("400")], // values to transfer
  ],
  // sum of native currency to transfer
  {
    value: parseEther("1000"),
  },
);
```

- Send **NFTs** - two ERC-721 to Alice, 100 ERC-1155 to Bob:

```javascript
await contract.write.beamTokens([
  // recipients
  [
    "0x00000000000000000000000000000000000a71CE",
    "0x00000000000000000000000000000000000a71CE",
    "0x0000000000000000000000000000000000000B0b",
  ],
  // token contract addresses
  [
    "0x7210000000000000000000000000000000000721",
    "0x7210000000000000000000000000000000000721",
    "0x1155000000000000000000000000000000001155",
  ],
  [721n, 721n, 1155n], // token types
  [42n, 69n, 420n], // token ids
  [1n, 1n, 100n], // values to transfer
]);
```

- Send ERC-20, ERC-712 and ERC-1155 to Alice

```javascript
await contract.write.beamTokens([
  // one recipient for all tokens
  ["0x00000000000000000000000000000000000a71CE"],
  // token contract addresses
  [
    "0x2000000000000000000000000000000000000020",
    "0x7210000000000000000000000000000000000721",
    "0x1155000000000000000000000000000000001155",
  ],
  [20n, 721n, 1155n], // token types
  [0n, 69n, 420n], // token ids
  [parseEther("600"), 1n, 100n], // values to transfer
]);
```

### Bulk token approval check

Additionally, the TokenBeamer contract offers a convenience method to check
approval states for multiple ERC-20, -721 and -1155 tokens for a given owner and
operator, before attempting to send them.

- Read approval state for different token types:

```typescript
const areContractsApproved: boolean[] = await contract.read.getApprovals([
   // owner of tokens
  "0x0000000000000000000000000000000000000B0b",
   // operator to check approvals for (e.g. the TokenBeamer contract)
  "0x09e2a70200000000000000000000000000000000",
  // token contract addresses
  [
    "0x2000000000000000000000000000000000000020",
    "0x7210000000000000000000000000000000000721",
    "0x1155000000000000000000000000000000001155",
  ],
  [20n, 721n, 1155n], // token types
  [parseEther("600"), 0n, 0n], // values to transfer (only relevant for ERC-20)
]): boolean[];

// returns the approval states for each token as an array of booleans, e.g.:
// -> [ true, true, false ]
// request approval for each token contract that returns `false` before sending
```

- If only checking NFTs (ERC-721, ERC-1155), you can drop token _types_ and
  _values_ completely:

```typescript
const areContractsApproved: boolean[] = await contract.read.getApprovals([
  // owner of tokens
  "0x00000000000000000000000000000000000a71CE",
  // approved operator
  "0x09e2a70200000000000000000000000000000000",
  // token contract addresses
  [
    "0x7210000000000000000000000000000000000721",
    "0x1155000000000000000000000000000000001155",
  ],
  [], // leave token types empty
  [], // leave values empty
]);
```

## License

GPL v3
