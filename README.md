# DLOBex

Submission to https://hedera22.devpost.com/  
tjdragonhash@gmail.com  

## Introduction

A [CLOB FIFO](https://en.wikipedia.org/wiki/Order_matching_system) is a typical order matching algorithm for centralized exchanges.

"While order book mechanisms are the dominant medium of exchange of electronic assets in traditional finance, they are challenging to use within a smart contract environment. The size of the state needed by an order book to represent the set of outstanding orders (e.g., passive liquidity) is large and extremely costly in the smart contract environment, where users must pay for space and compute power utilized" ([An analysis of Uniswap markets](https://web.stanford.edu/~guillean/papers/uniswap_analysis.pdf)).

The above is the reason why we have not seen decentralized CLOB in existing DEXs... until [Hedera](https://hedera.com/hh-ieee_coins_paper-200516.pdf).

DLOBex stands for **D**istributed **L**imit **O**rder **B**ook **ex**change.

Hedera's consensus is fast and settlement finality is deterministic. 
Using [Solidity](https://docs.soliditylang.org/) we will implement a permissioned exchange where users can trade [ERC20s](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/).  

Features implemented in this project:

- A smart contract that implements an order matching system using limit and market orders
- A permissioned contract where participants are vetted by a third-party
- A trade implementation using the ERC20 approve method with a penalizing system should the user misbehave
- A [CLI](https://en.wikipedia.org/wiki/Command-line_interface) to interact with the Smart Contract written in Java
- Support for HSM ([Hardware Security Module](https://en.wikipedia.org/wiki/Hardware_security_module))
- [May Be] An entitlement system with multi-signature for authentication and authorisation
- [May Be] A link to an Automated Market Maker contract whose inflection point is determined by the last traded price

## Definitions
### CLOB
A central limit order book is a usually represented as a bi-directional ladder, each side representing the buys and sells.
Taking the trading pair **HBAR/BTC** as an example (HBAR is the *base currency*, BTC is the *quoted currency*), 1 HBAR would cost at this time of writing 0.00000512 BTC. 
A design decision would be to only work with integers, therefore 1 HBAR equals to 512 Satoshis, the CLOB looks like this (based on different orders placed):

```text
HBAR/BTC pair
-------------
Buy         Sell
.	        500 @ 513
.	        50 @ 512
100 @ 511	.
80 @ 510	.
200 @ 509	.
```

The above order books shows that a seller is willing to sell 50 HBAR at 512, the buyer will get 50 HBAR for 50 * 512 = 25600 Satoshis.  
When this trade happens (Seller receives 25600 Satoshis, Buyer gets 50 HBAR), an atomic swap should happen on-chain (more on swaps later).  
Post trade the CLOB would update to:

```text
HBAR/BTC pair
-------------
Buy         Sell
.	        500 @ 513
100 @ 511	.
80 @ 510	.
200 @ 509	.
```

Conversely, if there is a buy for 50 lots at 511, the updated CLOB would look like:

```text
HBAR/BTC pair
-------------
Buy         Sell
.	        500 @ 513
50 @ 511	.
80 @ 510	.
200 @ 509	.
```

## Order Types
This project implements two order types: a **Market Order** and a **Limit Order**.

### Market Order
A Market Order would trade at the best price available, over multiple prices if required until the size has been consumed or if there is no more price.

### Limit Order
A Limit Order defines a price for a size - when placed it can result into a trade (partial or not), and will be placed in the CLOB if no match was found.

## ERC20
In this implementation, any [ERC20](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/) can be traded on Hedera.  
To make the implementation generic, we would wrap HBAR into an ERC20 (like the equivalent of WETH for ETH), but we can obviously wrap any fiat into a stable coin:
HUSD would represent a USD stable coin, or HEUR for a EUR stable coin. (Banks could be the issuer of those currencies, Crypto-firms could issue the HETH, HHBAR, HBTC, ...).  
The CLOB contract would be instantiated with the addresses of the two ERC20s.

## Permissioning 
The contract owner will vet participants and will have the ability to stop and start trading.

## Settlement
Once a trade has happened between two parties, those parties have to deliver. Potential failure to deliver is called [Settlement Risk](https://www.investopedia.com/terms/s/settlementrisk.asp): 
when Bob sends 50 HBAR to Alice, Alice must send 25600 Satoshis to Bob.  

There are several approaches to this. Let's discuss the different options.  
There are pros and cons for each approach, but conceptually, either a user delegates the asset to the smart contract for settlement purposes (but also require the smart contract to allow withdrawal of that asset), or the user keeps the ownership of that asset but allows the smart contract, via ERC20's method 'approve', to transfer that asset (with the drawback that the user couldtransfer this asset prior to settlement failing the transfer should a trade happen!)

### Delegation to the Smart Contract via Approve
The ERC20 'Approve' method allows an asset owner to delegate the ability to transfer said asset to a third-party.  

Pros:  
- The user keeps ownership of that asset;
- The user decides the maximum amount that can be delegated
- The user can cancel at anytime this delegation

Cons:  
- Prior to settlement, the user can transfer the asset, regardless of the delegation amount, therefore failing settlement (hence the implementation of a fee for misbehaving)

### Transfer to the Smart Contract
In this scenario, the use transfers the maximum amount to trade to the smart contract:

Pros:  
- No settlement risk - what you have is what you can trade

Cons:  
- The user must invoke an operation for withdrawal (transfer back from smart contract to the user)

### Solution implemented
For illustration purposes we will implement the 'Approve' option with a penalization system should the user misbehave (it could be a retainer of 1% of the approved amount to the smart contract owner for example).

## Development and testing
The development and testing environment uses [VS Code](https://code.visualstudio.com/) and [Hardhat](https://hardhat.org/).  
The source code for this project can be found on [GitHub hedera22](https://github.com/tjdragon/hedera22) for the Solidity code and on [GitHub hedera22-cli](https://github.com/tjdragon/hedera22-cli) for the CLI.

## Design choices
[Hedera's contract service](https://hedera.com/smart-contract) is EVM-based, therefore the main contract will be implemented using [Solidity](https://docs.soliditylang.org/).  
This approach is quite flexible because it allows the "[Write Once, Run Anywhere](https://en.wikipedia.org/wiki/Write_once,_run_anywhere)" approach: i.e. develop in Solidity and run on [Ethereum](https://ethereum.org/en/),
[Solana](https://soliditydeveloper.com/solana) and of course [Hedera](https://hedera.com/).  
[Java](https://www.java.com/en/) is used for deployment and interaction.

## Implementation details

Emphasis has been placed on functionality not optimization ;-)

### ERC20

A classic openzeppelin implementation, allowing adding custom methods which can be useful specifically for stable coins (whitelisting, burning, minting, ...).

```solidity
//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Gen20Token is ERC20 {
    constructor(
        uint256 initialSupply, 
        string memory name, 
        string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}
```

### Order
An order is represented as a struct:

```solidity
struct Order {
    uint256 id_int; // Internal Order Id
    uint256 id_ext; // External Order Id
    address owner; // Owner
    bool is_buy; // Is this a Buy or Sell 
    uint256 size; // Size
    uint256 price; // Price (0 for Market Orders)
}
```

- If 'price' is provided, it is considered a limit order, otherwise, it is a market order.
- id_int is the internal order id

### Prices and Sizes
Prices and Sizes are presented as integers. 
For Trading, each ERC20 should define a number of decimals.  
In FX, this number is 4, using integers simplifies testing.  
For example a 3.1415 price is represented as 31415.  
This implementation is out of scope for this project.

### Orders list
Orders are sorted by price. While there are some existing generic libraries available, I have decided to go for a simpler approach: sort on insert.

## Deployment and testing
### Hardhat deployment and testing
Deploy the two required ERC 20 tokens (We are using a HBAR/HUSD pair with an initial supply of 1000000):

```javascript
const Gen20Token = await ethers.getContractFactory("Gen20Token");
const _hbar_token = await Gen20Token.deploy(1000000, "HBAR", "HBAR");
await _hbar_token.deployed();
const _husd_token = await Gen20Token.deploy(1000000, "HUSD", "HUSD");
await _husd_token.deployed();
```

Deploy the main contract:
```javascript
const DLOBEX = await ethers.getContractFactory("DLOBEX");
const _dlobex = await DLOBEX.deploy(_hbar_token.address, _husd_token.address);
await _dlobex.deployed();
```

Transfer 200000 tokens to the two paricipants:
```javascript
await _hbar_token.transfer(_participant_1.address, 200000);
await _hbar_token.transfer(_participant_2.address, 200000);
await _husd_token.transfer(_participant_1.address, 200000);
await _husd_token.transfer(_participant_2.address, 200000);
```

Each participant must allow the smart contract to spend the tokens in case of a trade:

```javascript
await _husd_token.connect(_participant_1).approve(_dlobex.address, 10000);
await _hbar_token.connect(_participant_2).approve(_dlobex.address, 10000);
```

Finally, placing a limit order looks like:
```javascript
await _dlobex.connect(_participant_1).place_limit_order(1, true, 50, 22);
```

In order to visualise the order book, call:
```javascript
await _dlobex.print_clob();
```

### Hedera tesnet deployment and testing
We will use Java to deploy and test the Solidity code.  
You need to compile your solidity code using solc:

```shell
solcjs --base-path . --include-path node_modules --optimize --bin --abi -o abis contracts/Gen20Token.sol      
solcjs --base-path . --include-path node_modules --optimize --bin --abi -o abis contracts/DLOBEX.sol      
```

Alternatively, you can compile with VS.Code and go to the directory artifacts/contracts and get the relevant JSON.

The Java code to deploy any Solidity contracts looks like the one below - used to deploy ERC20 tokens:

```java
package org.tj.hedera22;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.hedera.hashgraph.sdk.*;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.util.Objects;
import java.util.concurrent.TimeoutException;

public final class DeployERC20 {
    private DeployERC20() {
    }

    public static void main(String[] args) throws PrecheckStatusException, TimeoutException, IOException, ReceiptStatusException {
        long t0 = System.currentTimeMillis();

        final ClassLoader cl = DeployERC20.class.getClassLoader();
        final Gson gson = new Gson();
        JsonObject jsonObject;

        try (InputStream jsonStream = cl.getResourceAsStream("Gen20Token.json")) {
            if (jsonStream == null) {
                throw new RuntimeException("Failed to get Gen20Token.json");
            }
            jsonObject = gson.fromJson(new InputStreamReader(jsonStream, StandardCharsets.UTF_8), JsonObject.class);
        }

        final String byteCodeHex = jsonObject.getAsJsonPrimitive("bytecode").getAsString();
        final byte[] byteCode = byteCodeHex.getBytes(StandardCharsets.UTF_8);

        final Client client = HederaClient.CLIENT_TESTNET;

        client.setOperator(Accounts.OPERATOR_ID, Accounts.OPERATOR_KEY);

        client.setDefaultMaxTransactionFee(new Hbar(1000000));
        client.setDefaultMaxQueryPayment(new Hbar(100000));

        final TransactionResponse fileTransactionResponse = new FileCreateTransaction()
                .setKeys(Accounts.OPERATOR_KEY)
                .setContents("")
                .execute(client);

        final TransactionReceipt fileReceipt = fileTransactionResponse.getReceipt(client);
        final FileAppendTransaction fat = new FileAppendTransaction()
                .setFileId(fileReceipt.fileId)
                .setMaxChunks(40);
        fat.setContents(byteCode);
        fat.execute(client);

        final FileId newFileId = Objects.requireNonNull(fileReceipt.fileId);

        long tf = (System.currentTimeMillis() - t0) / 1000;
        System.out.println(tf + " secs. Contract bytecode file: " + newFileId);

        final TransactionResponse contractTransactionResponse = new ContractCreateTransaction()
                .setBytecodeFileId(newFileId)
                .setGas(4000000)
                .setConstructorParameters(
                        new ContractFunctionParameters()
                                .addUint256(BigInteger.valueOf(200_000))
                                .addString("HBA")
                                .addString("HBA")
                )
                .execute(client);

        try {
            final TransactionReceipt contractReceipt = contractTransactionResponse.getReceipt(client);
            final ContractId newContractId = Objects.requireNonNull(contractReceipt.contractId);
            System.out.println("Gen20Token contract ID: " + newContractId);
            System.out.println("Gen20Token Solidity address: " + newContractId.toSolidityAddress());
        } catch (ReceiptStatusException e) {
            e.printStackTrace();
        }
    }
}
```

The code above returns a contract id of **0.0.34101006** for a contract address **000000000000000000000000000000000208570e**.

You have noticed that I have been using an operator id and private key to do the deployment. The next section will show you
how to create new Hedera users for testing.

### Creating an Hedera testnet account
```java
package org.tj.hedera22;

import com.hedera.hashgraph.sdk.*;

import java.util.Base64;
import java.util.concurrent.TimeoutException;
import java.util.function.Function;

public class CreateAccount {
    public static void main(String[] args) throws PrecheckStatusException, TimeoutException, ReceiptStatusException {
        System.out.println("CreateAccount via HSM");

        // Create HSM an Ed25519 key pair - Here we simulate via software
        final PrivateKey customerPrivateKey = PrivateKey.generate();
        final PublicKey customerPublicKey = customerPrivateKey.getPublicKey();
        System.out.println("customerPublicKey: " + Base64.getEncoder().encodeToString(customerPublicKey.toBytes()));

        final AccountId operatorId = Accounts.OPERATOR_ID;
        final PrivateKey operatorPrivateKey = Accounts.OPERATOR_KEY;

        final Client client = HederaClient.CLIENT_TESTNET;
        client.setOperator(operatorId, operatorPrivateKey);

        final TransactionResponse transactionResponse = new AccountCreateTransaction()
                .setReceiverSignatureRequired(false) // Must be true for FATF-16
                .setKey(customerPublicKey)
                .freezeWith(client)
                .signWith(operatorPrivateKey.getPublicKey(), signWithHsm(operatorPrivateKey))
                .execute(client);

        final TransactionReceipt transactionReceipt = transactionResponse.getReceipt(client);
        System.out.println(transactionReceipt.status.toString() + " - New account id " + transactionReceipt.accountId);
    }

    private static Function<byte[],byte[]> signWithHsm(final PrivateKey operatorPrivateKey) {
        return (
                operatorPrivateKey::sign
        );
    }
}
```

The above code makes reference to a HSM (Hardware Security Module), we will tackle this later on. For now we generate key pairs use the
Hedera SDK which uses [Bouncycastle](https://www.bouncycastle.org/). The code above returned **0.0.34111165** as an account id.  

### Set-up logic
Once the contracts have been deployed and the participants created, the logic is simply to transfer some tokens to the participants,
then each participant would approve the contract to spend them. 
Finally, a CLI program has been created to interact with the main smart contract: display order book, check balances and approvals and
issue limit and market orders.

```text
[main] INFO org.tj.hedera22.CLI - Hedera Menu. Please select an option:
[main] INFO org.tj.hedera22.CLI -  Acting account: 0.0.7599 (Operator)
[main] INFO org.tj.hedera22.CLI -    1. Exit
[main] INFO org.tj.hedera22.CLI -    2. Allow Trading (~ 1ℏ)
[main] INFO org.tj.hedera22.CLI -    3. Stop Trading (~ 1ℏ)
[main] INFO org.tj.hedera22.CLI -    4. Add All Participants (~ 2ℏ)
[main] INFO org.tj.hedera22.CLI -    5. Select participant (free)
[main] INFO org.tj.hedera22.CLI -    6. Display order book (~ 7ℏ)
[main] INFO org.tj.hedera22.CLI -    7. Place Limit Order (~ 1ℏ)
[main] INFO org.tj.hedera22.CLI -    8. Place Market Order (~ 1ℏ)
[main] INFO org.tj.hedera22.CLI -    9. Display balances (~ 8ℏ)
[main] INFO org.tj.hedera22.CLI -    10. Display trading allowed status (~ 0.1ℏ)
[main] INFO org.tj.hedera22.CLI -    11. Display latest debug (~ 0ℏ)
[main] INFO org.tj.hedera22.CLI -    12. Reset
```

Please note the costs for each operation to execute. For example, placing an order costs around 1ℏ, whereas displaying the order book costs around ~ 7ℏ.  
Other functions could be added to reduce the costs: best buy/sell price (already implemented), last traded buy/sell price, total buy/sell volume, ...

The java source code can be found [there](https://github.com/tjdragon/hedera22-cli) and make sure you read the [readme](https://github.com/tjdragon/hedera22-cli#readme) as well before you start.

## Java code

Java code to interact with Hedera in TESTNET
Before you start
Accounts
Using your operator account and private (Set them in Accounts), create two other accounts for the participants and update the Accounts.java file. Use CreateAccount to create them

Deploy the contracts
Use DeployERC20 twice with the relevant token info (name, supply) and DeployDLOBEx for the main smart contract.
Note the deployment uses testnet and use your operator account.

Transfer some native HBARs to the participants
For the participants to be able to interact with the native chain, transfer some native HBARs to them using TransferHBARs.
You can then use CLI with the option "Display balances" to confirm.

Transfer some tokens to the participants.
Same as above, but using TransferTokens

You should see on the CLI:

```text
[main] INFO org.tj.hedera22.CLI - Displaying balances... (gas used: 320000)
[main] INFO org.tj.hedera22.CLI -  Operator: 9560.53196754 ℏ
[main] INFO org.tj.hedera22.CLI -  Participant 1: 200 ℏ, HHBAR Owned: 50000, HUSD Owned: 50000, HHBAR Allowance: 0, HUSD Allowance: 0
[main] INFO org.tj.hedera22.CLI -  Participant 2: 200 ℏ, HHBAR Owned: 50000, HUSD Owned: 50000, HHBAR Allowance: 0, HUSD Allowance: 0
```

Approve
The next step is to allow the smart contract DeployDLOBEx to spend your tokens post trade.
This is done with ApproveTransfer.

Finally, the last state from the CLI, you should also see the allowance:

```text
[main] INFO org.tj.hedera22.CLI - Displaying balances... (gas used: 320000)
[main] INFO org.tj.hedera22.CLI -  Operator: 9552.52838234 ℏ
[main] INFO org.tj.hedera22.CLI -  Participant 1: 199.27539722 ℏ, HHBAR Owned: 50000, HUSD Owned: 50000, HHBAR Allowance: 50000, HUSD Allowance: 50000
[main] INFO org.tj.hedera22.CLI -  Participant 2: 199.27539722 ℏ, HHBAR Owned: 50000, HUSD Owned: 50000, HHBAR Allowance: 50000, HUSD Allowance: 50000
```

## Local testing

Please refer to [Hedera Services](https://github.com/hashgraph/hedera-services)

## Support for HSM

## Hedera's readiness for FATF-16
[FATF](https://www.fatf-gafi.org/publications/fatfrecommendations/documents/fatf-recommendations.html) *recommendations set out a comprehensive and consistent framework of measures which countries should implement in order to combat money laundering and terrorist financing, as well as the financing of proliferation of weapons of mass destruction.*  
There are several initiatives at work, namely [TRP](https://www.travelruleprotocol.org/), [OpenVASP](https://openvasp.org/) and 
[TRUST](https://www.crowdfundinsider.com/2022/02/187092-travel-rule-universal-solution-technology-trust-is-solution-for-fatf-travel-rule/).  

Hedera simplifies FATF-16 by avoiding the need to quarantine assets: at the account creation, we can set up the account with the following option:

```java
final TransactionResponse transactionResponse = new AccountCreateTransaction()
    .setReceiverSignatureRequired(true) ...
```

When using an off-chain protocol (TRP/OpenVasp/TRUST), with the exchange of KYC information and address owernship and provevance, the receiver
can sign the incoming transfer for it to be effective.

## Maker-Checker
All financial systems implement the concept of [Maker-Checker](https://en.wikipedia.org/wiki/Maker-checker).  
One way to achieve this would be by the use of [ScheduleCreateTransaction](https://github.com/hashgraph/hedera-sdk-java/blob/main/examples/src/main/java/ScheduleMultiSigTransactionExample.java) although this process requires n-of-n signers as opposed to the more flexible n-of-m.  
There is room for improvement, where setKey should be augmented with a Rule to be evaluated at runtime.  
Such a Rule could implement a simple tree structure with OR/AND, and once evaluated to true, the transaction would go through.  

## Improvements
- The Solidity code is not optimized and lots of careful love is required to make it more gas-efficient.  
- Build a web site to display the order book and integrate with a Metamask-like plugin and/or integrate with a Nano ledger.
- Use the average buy/sell order prices post trade as a dynamic inflection point for AMM implementations.
- Implement FATF-16 by default for native HBARs.
- Implement Maker-Checker by default.
- Port Uniswap to Hedera

Many thanks

TJ-Dragon-Hash
