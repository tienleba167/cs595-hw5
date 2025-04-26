# 🛡️ Homework Assignment: Build a Privacy Preserving Asset Transfer Mechanism with Noir on Ethereum

---

## 📏 Overview

In this assignment, you’ll build a **privacy preserving asset transfer mechanism**, where users can deposit and withdraw ETH anonymously using smart contracts and **zero-knowledge proofs**.

A way to have privacy on-chain is to pool all money in one contract. Instead of party A sending money directly to party B, party A sends the money to a pool where party B can later fetch the money at will.

In this homework we are going to create a simple example of that. When a party A wants to deposit to the contract, it will commit to a secret id together with some random nonce and put it in a Merkle tree as a leaf. Later, party B can prove that it knows a leaf with that secret together with the proper opening path, but it will not disclose which leaf,thus breaking the link between the sender and receiver (if the contract is being used enough).

To prevent double spending, we ask party B to reveal a unique identifier ("nullifier") as part of the proof. This allows the smart contract to keep track of utilized nullifiers. If the same nullifier appears again, the contract will reject the withdrawal, preventing double spending without compromising privacy. This is similar to the Sanders Ta-Shma protocol seen in class, as part of the Zerocash protcol.

For this homework we will restrict all deposits and withdrawals to 0.1 ETH.

---

## 💡 Background

You have already implemented an off-chain Merkle tree in **Lab 2** with noir and solidity to prove that a party has a credit score larger than a threshold amount. In this assignment, we will use the same tools to manage ETH deposits and withdrawals privately.

---

## Summary of Work Completed
✅ Noir Circuits Written:

deposit.nr: Proves insertion into a Merkle tree.

withdraw.nr: Proves membership of a commitment without revealing the index.

✅ Circuit Compilation:

nargo compile was used to compile both deposit-circuit and withdraw-circuit.

✅ Verifier Contracts Generated:

bb write_vk was used to generate the verification keys.

bb write_solidity_verifier was used to generate DepositVerifier.sol and WithdrawVerifier.sol.

✅ Smart Contract Ready:

whirlwind.sol manages deposits, withdrawals, and on-chain state updates.

Takes the addresses of the verifier contracts during deployment.

### Commands Used

1. Compile the Circuits

```
cd circuits/deposit-circuit

nargo compile

```

```
cd circuits/withdraw-circuit

nargo compile

```

2. Generate Verifier Solidity Contracts

For Deposit Circuit
```
mkdir -p ./target/vk

bb write_vk --scheme ultra_honk --oracle_hash keccak -b ./target/deposit_circuit.json -o ./target/vk

bb write_solidity_verifier --scheme ultra_honk -k ./target/vk/vk -o ./target/DepositVerifier.sol
```

For Withdraw Circuit
```
mkdir -p ./target/vk

bb write_vk --scheme ultra_honk --oracle_hash keccak -b ./target/withdraw_circuit.json -o ./target/vk

bb write_solidity_verifier --scheme ultra_honk -k ./target/vk/vk -o ./target/WithdrawVerifier.sol
```

3. Move Verifiers to Contracts Directory
```
mv circuits/deposit-circuit/target/DepositVerifier.sol contracts/

mv circuits/withdraw-circuit/target/WithdrawVerifier.sol contracts/
```

## 🧱 Smart Contract Explanation

We provide you with a smart contract (named `Whirlwind`) that manages the deposit and withdrawal operations on-chain. The key responsibilities of this contract include:

- **State Management:**  
  - Storing the current Merkle tree root.
  - Tracking the number of deposits via an internal index.
  - Maintaining a mapping of used nullifiers to prevent double spending.

- **Verification:**  
  - The contract uses verifier contracts (generated from your Noir circuits) to automatically check the validity of both deposit and withdrawal proofs.
  
- **Fund Handling and Events:**  
  - Deposits are accepted (exactly 0.1 ETH per deposit) and update the Merkle tree root.
  - Withdrawals transfer 0.1 ETH to the caller if the provided proof is valid and the nullifier hasn’t been used.
  - It emits events to help track deposits and withdrawals.

Your job is to create the deposit and withdraw circuits in Noir, compile them to produce their respective verifier contracts (e.g., `DepositVerifier.sol` and `WithdrawVerifier.sol`), and then feed these verifier contract addresses to the constructor of the provided smart contract during deployment.

Below is the provided contract:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVerifier {
    function verify(bytes calldata proof, bytes32[] calldata publicInputs) external view returns (bool);
}

contract Whirlwind {
    address public depositVerifier;
    address public withdrawVerifier;

    // Deposit index to track the number of deposits
    uint256 public depositIndex;
    // Maximum allowed deposits computed from the Merkle tree depth
    uint256 public maxDeposits;

    mapping(bytes32 => bool) public usedNullifiers;
    bytes32 public currentRoot;

    event Deposit(bytes32 newRoot, bytes32 commitment, uint256 index);
    event Withdraw(address indexed recipient, bytes32 nullifier);

    address public owner;

    // Constructor sets verifier addresses, owner, and computes the maximum number of leaves
    constructor(address _depositVerifier, address _withdrawVerifier, uint256 _merkleTreeDepth, bytes32 _initialRoot) {
        owner = msg.sender;
        depositVerifier = _depositVerifier;
        withdrawVerifier = _withdrawVerifier;
        maxDeposits = 2 ** _merkleTreeDepth;
        currentRoot = _initialRoot;
    }

    // Deposit function uses the internal depositIndex and checks against maxDeposits
    function deposit(bytes calldata proof, bytes32 newRoot, bytes32 commitment) external payable {
        require(depositIndex < maxDeposits, "Deposit limit reached");
        // Create a dynamic bytes32 array in memory with 4 elements
        bytes32[] memory publicInputs = new bytes32[](4);

        publicInputs[0] = currentRoot;
        publicInputs[1] = newRoot;
        publicInputs[2] = commitment;
        publicInputs[3] = bytes32(uint256(depositIndex)); // if depositIndex is uint256

        require(msg.value == 0.1 ether, "Must deposit exactly 0.1 ETH");
        require(IVerifier(depositVerifier).verify(proof, publicInputs), "Invalid deposit proof");

        currentRoot = newRoot;
        emit Deposit(newRoot, commitment, depositIndex);
        depositIndex++; // Increment internal deposit index
    }

    function withdraw(bytes calldata proof, bytes32 nullifier) external {
        require(!usedNullifiers[nullifier], "Nullifier already used");
        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = currentRoot;
        publicInputs[1] = nullifier;
        require(IVerifier(withdrawVerifier).verify(proof, publicInputs), "Invalid withdraw proof");

        usedNullifiers[nullifier] = true;
        emit Withdraw(msg.sender, nullifier);
        payable(msg.sender).transfer(0.1 ether);
    }
}
```

---

## ✅ High-Level Protocol

This section explains the processes underlying the deposit and withdraw operations, along with a note on verifier generation:


### 🔹 Deposit (0.1 ETH)

- **User Steps:**
  - Choose a random `id` (serves as the nullifier base) and a random blinding factor `r`.
- **Computation:**
  ```js
  commitment = PedersenHash(id, r)
  ```
- **Process:**
  - Insert `commitment` into the off-chain Merkle tree. Note that the state of the offchain Merkle tree must match the one on chain.
  - Generate a zero-knowledge (ZK) proof showing that the Merkle tree has been correctly updated with the new commitment.
- **On-Chain:**
  - The provided smart contract’s deposit function (which utilizes the automatically generated verifier from Noir) checks the proof.
  - Upon verification, the contract updates its state with the new Merkle tree root and emits the event:
    ```solidity
    event Deposit(bytes32 newRoot, bytes32 commitment, uint256 index);
    ```

### 🔹 Withdraw (0.1 ETH)

- **User Steps:**
  - Prepare a proof that you know a valid nullifier `id` satisfying:
    - `commitment = PedersenHash(id, r)` is present in the Merkle tree (verified via a Merkle path).
- **On-Chain:**
  - The withdraw function (leveraging the Noir-generated verifier) checks the proof.
  - If valid and the nullifier `id` is unused, 0.1 ETH is transferred to the caller, the nullifier is marked as used, and an event is emitted:
    ```solidity
    event Withdraw(address indexed recipient, bytes32 nullifier);
    ```

**Note:** The deposit and withdraw verifier contracts are automatically generated by compiling your Noir circuits. These verifier contracts are then plugged into the provided smart contract.

---

## 🧐 Noir Circuit Requirements

The Noir circuit implementations are split into two projects: one for deposit and one for withdraw. Noir currently supports generating only one verifier per project, so you must create two separate projects.

### `deposit.nr`

#### **Private Inputs**

- `id: Field`
- `r: Field`
- The old Merkle tree path to the empty leaf (`oldPath: [Field; depth]`)

#### **Public Inputs**

- `oldRoot: Field`
- `newRoot: Field`
- `commitment: Field` (which must equal `PedersenHash(id, r)`)
- `Leaf index: Field`

#### **Constraints Proven**

- That `commitment == PedersenHash(id, r)`
- A new Merkle tree root is correctly computed by inserting `commitment` at the specified index, updating the old path.
- The provided old Merkle path is valid for `oldRoot`.

---

### `withdraw.nr`

#### **Private Inputs**

- `r: Field`
- Leaf `index: Field`
- Merkle `path: [Field; depth]`

#### **Public Inputs**

- `root: Field`
- `id: Field` (serving as the nullifier)

#### **Constraints Proven**

- The circuit proves that the value `PedersenHash(id, r)` exists within the tree at the given `index` along the provided `path`.
- It confirms that the supplied `root` is the correct Merkle tree root corresponding to this path.
- The nullifier is properly computed.

---

## 📁 Deliverables

Your repository should include the following structure:

```
/whirlwind/
│
├── circuits/
│   ├── deposit-circuit/        # Noir project for deposit
│   │   ├── src/deposit.nr      # You should write this
│   │   ├── Nargo.toml
│   │   └── Prover.toml         # You should write this
│   └── withdraw-circuit/       # Noir project for withdraw
│       ├── src/withdraw.nr     # You should write this
│       ├── Nargo.toml
│       └── Prover.toml         # You should write this
│
├── contracts/
│   ├── whirlwind.sol         # Provided main contract
│   └── (generated) DepositVerifier.sol / WithdrawVerifier.sol # you should generate this
│
│
└── README.md
```

> ⚠️ **Note:** Noir currently supports generating only **one verifier** per project. Therefore, you must create **two separate Noir projects**: one for the deposit circuit and one for the withdraw circuit. Each must be compiled independently using:
>
> ```bash
> bb write_solidity_verifier --scheme ultra_honk -k ./target/vk -o ./target/DepositVerifier.sol
> bb write_solidity_verifier --scheme ultra_honk -k ./target/vk -o ./target/WithdrawVerifier.sol
> ```

---


## 🔸 Generating TOML Files with `demo.ts`

To generate the TOML files needed for your Noir circuits, you can run the provided `demo.ts` script. This demo shows how to initialize the off-chain Merkle tree, perform a deposit (generating the deposit TOML file), and produce the corresponding withdraw TOML file for a recorded deposit.

### How to Use:

1. **Run the Demo Script:**  
   Execute the demo using Node.js (located in hw5/gen_toml/src/):
   ```bash
   npx ts-node demo.ts
   ```

2. **Review the Output:**  
   The script will print out the generated TOML files to the console. These files include:
   - **Deposit TOML File:** Contains the inputs required by the deposit circuit (i.e. `id`, `r`, `hashpath`, `oldRoot`, `newRoot`, `commitment`, and `index` as an Fr element).
   - **Withdraw TOML File:** Contains the inputs required by the withdraw circuit (i.e. `r`, `index`, `hashpath`, `root`, and `id`).

3. **Use the TOML Files:**  
   Copy the TOML output into the respective input files and feed them into your Noir proof generation process.

---
### 🔍 Off-Chain Merkle Tree Details

The provided off-chain Merkle tree (from Lab 2) is being used when generating the .toml files :

- **Creating an Empty Merkle Tree:**  
  ```js
  const tree = new MerkleTree(8);  // for a tree of depth 8
  // Each empty leaf has the default value:
  // 0x18d85f3de6dcd78b6ffbf5d8374433a5528d8e3bf2100df0b7bb43a4c59ebd63
  ```

- **Inserting a Commitment:**  
  ```js
  tree.insert(commitment);
  ```

- **Retrieving the Current Root:**  
  ```js
  tree.root().toString();
  ```

- **Retrieving a Merkle Authentication Path:**  
  ```js
  console.log('Proof details:');
  console.log('  Leaf:', proof.leaf.toString());
  console.log('  Root:', proof.root.toString());
  console.log('  Path Elements:', proof.pathElements.map(fr => fr.toString()));
  console.log('  Path Indices:', proof.pathIndices);
  ```

---
