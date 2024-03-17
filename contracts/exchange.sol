// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./token.sol";
import "hardhat/console.sol";

contract TokenExchange is Ownable {
    string public exchange_name = "";

    // TODO: paste token contract address here
    // e.g. tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3
    address tokenAddr = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    // TODO: paste token contract address here
    Token public token = Token(tokenAddr);

    // Liquidity pool for the exchange
    uint private token_reserves = 0;
    uint private eth_reserves = 0;

    // Fee Pools
    uint private token_fee_reserves = 0;
    uint private eth_fee_reserves = 0;

    // Liquidity pool shares
    mapping(address => uint) private lps;

    // For Extra Credit only: to loop through the keys of the lps mapping
    address[] private lp_providers;

    // Total Pool Shares
    uint private total_shares = 0;

    // liquidity rewards
    uint private swap_fee_numerator = 3;
    uint private swap_fee_denominator = 100;

    // Constant: x * y = k
    uint private k;

    uint private multiplier = 10 ** 5;

    event AddLiquidity(address indexed provider, uint amountTokens, uint amountETH);


    constructor() {}

    // Function createPool: Initializes a liquidity pool between your Token and ETH.
    // ETH will be sent to pool in this transaction as msg.value
    // amountTokens specifies the amount of tokens to transfer from the liquidity provider.
    // Sets up the initial exchange rate for the pool by setting amount of token and amount of ETH.
    function createPool(uint amountTokens) external payable onlyOwner {
        // This function is already implemented for you; no changes needed.

        // require pool does not yet exist:
        require(token_reserves == 0, "Token reserves was not 0");
        require(eth_reserves == 0, "ETH reserves was not 0.");

        // require nonzero values were sent
        require(msg.value > 0, "Need eth to create pool.");
        uint tokenSupply = token.balanceOf(msg.sender);
        require(
            amountTokens <= tokenSupply,
            "Not have enough tokens to create the pool"
        );
        require(amountTokens > 0, "Need tokens to create pool.");

        token.transferFrom(msg.sender, address(this), amountTokens);
        token_reserves = token.balanceOf(address(this));
        eth_reserves = msg.value;
        k = token_reserves * eth_reserves;

        // Pool shares set to a large value to minimize round-off errors
        total_shares = 10 ** 5;
        // Pool creator has some low amount of shares to allow autograder to run
        lps[msg.sender] = 100;
    }

    // For use for ExtraCredit ONLY
    // Function removeLP: removes a liquidity provider from the list.
    // This function also removes the gap left over from simply running "delete".
    function removeLP(uint index) private {
        require(
            index < lp_providers.length,
            "specified index is larger than the number of lps"
        );
        lp_providers[index] = lp_providers[lp_providers.length - 1];
        lp_providers.pop();
    }

    // Function getSwapFee: Returns the current swap fee ratio to the client.
    function getSwapFee() public view returns (uint, uint) {
        return (swap_fee_numerator, swap_fee_denominator);
    }

    // Function getReserves
    function getReserves() public view returns (uint, uint) {
        return (eth_reserves, token_reserves);
    }

    // ============================================================
    //                    FUNCTIONS TO IMPLEMENT
    // ============================================================

    /* ========================= Liquidity Provider Functions =========================  */

    // Function addLiquidity: Adds liquidity given a supply of ETH (sent to the contract as msg.value).
    // You can change the inputs, or the scope of your function, as needed.
    function debugPrint() public view {
        console.log("eth_reserves: ", eth_reserves);
        console.log("token_reserves: ", token_reserves);
        console.log("k: ", k);
        console.log("total_shares: ", total_shares);
    }

    function printAccount(address _addr) public view {
        console.log("eth: ", address(_addr).balance);
        console.log("token: ", token.balanceOf(address(_addr)));
        console.log("shares: ", lps[_addr]);
    }
    
    function addLiquidity() external payable {
        /******* TODO: Implement this function *******/
        uint amountETH = msg.value;
        uint amountTokens = amountETH * token_reserves / eth_reserves;
        printAccount(msg.sender);
        // msg này đưa cho client ntn? -> báo qua ethers js về console 
        require(
            amountTokens <= token.balanceOf(msg.sender),
            "Not enough token balance"
        );
        eth_reserves += amountETH;
        // cần dòng nào trong 2 dòng dưới
        uint shares = total_shares * (amountTokens + token_reserves) / token_reserves - total_shares;
        token_reserves += amountTokens;
        token.transferFrom(msg.sender, address(this), amountTokens);
        // TODO update shares
        lps[msg.sender] += shares;
        k = token_reserves * eth_reserves;
        total_shares += shares;

        debugPrint();
        printAccount(msg.sender);

        emit AddLiquidity(msg.sender, amountTokens, amountETH);
    }

    modifier notEmptyReserves(uint amountETH) {
        // amountETH = toWei(amountETH);
        uint amountTokens = (amountETH * token_reserves) / eth_reserves;
        uint new_token_reserves = token_reserves - amountTokens;
        uint new_eth_reserves = eth_reserves - amountETH;
        // check if there is enough reserves
        require(new_eth_reserves > 0, "Not enough eth reserves");
        require(new_token_reserves > 0, "Not enough token reserves");
        _;
    }


    function _enoughShares(uint shares) private view returns (bool) {
        return shares <= lps[msg.sender];
    }


    // Function removeLiquidity: Removes liquidity given the desired amount of ETH to remove.
    // You can change the inputs, or the scope of your function, as needed.
    function removeLiquidity(
        uint amountETH
    ) public payable notEmptyReserves(amountETH * (10**18)) {
        /******* TODO: Implement this function *******/
        amountETH = amountETH * (10**18);
        uint amountTokens = (amountETH * token_reserves) / eth_reserves;
        // TODO check logic
        // check if provider is entitled -> has enough shares
        uint sharesToWithdraw = (amountTokens * total_shares) / token_reserves ;
        console.log("amountTokens: ", amountTokens);
        debugPrint();

        console.log("sharesToWithdraw: ", sharesToWithdraw); 
        require(_enoughShares(sharesToWithdraw), "Not enough shares");

        uint new_token_reserves = token_reserves - amountTokens;
        uint new_eth_reserves = eth_reserves - amountETH;

        // update reserves
        token_reserves = new_token_reserves;
        eth_reserves = new_eth_reserves;
        token.transfer(msg.sender, amountTokens);
        payable(msg.sender).transfer(amountETH);
        // update shares
        lps[msg.sender] -= sharesToWithdraw;
        total_shares -= sharesToWithdraw;
        k = token_reserves * eth_reserves;

        debugPrint();
        printAccount(msg.sender);
    }

    // Function removeAllLiquidity: Removes all liquidity that msg.sender is entitled to withdraw
    // You can change the inputs, or the scope of your function, as needed.
    function removeAllLiquidity() external payable {
        /******* TODO: Implement this function *******/
        uint amountTokens = (token_reserves * lps[msg.sender]) / total_shares;
        uint amountETH = (eth_reserves * lps[msg.sender]) / total_shares;

        debugPrint();
        console.log("amountTokens: ", amountTokens);

        uint new_token_reserves = token_reserves - amountTokens;
        uint new_eth_reserves = eth_reserves - amountETH;
        // check if there is enough reserves
        require(new_eth_reserves > 0, "Not enough eth reserves");
        require(new_token_reserves > 0, "Not enough token reserves");

        // call token contract to approve transfer
        token.approve(address(this), amountTokens);
        token.transfer(msg.sender, amountTokens);

        token_reserves = new_token_reserves;
        eth_reserves = new_eth_reserves;
        total_shares -= lps[msg.sender];
        lps[msg.sender] = 0;
        k = token_reserves * eth_reserves;

        debugPrint();
        printAccount(msg.sender);
    }
    /***  Define additional functions for liquidity fees here as needed ***/

    /* ========================= Swap Functions =========================  */

    // Function swapTokensForETH: Swaps your token with ETH
    // You can change the inputs, or the scope of your function, as needed.
    function swapTokensForETH(uint amountTokens) external payable {
        /******* TODO: Implement this function *******/
        uint newTokenReserves = token_reserves + amountTokens;
        uint newEthReserves = k / newTokenReserves;
        uint amountETH = eth_reserves - newEthReserves ;

        // check not empty reserves
        require(newEthReserves > 0, "Not enough eth reserves");

        // transfer token from sender to contract
        token.transferFrom(msg.sender, address(this), amountTokens);
        // transfer eth from contract to sender
        payable(msg.sender).transfer(amountETH);
        // update reserves
        token_reserves = newTokenReserves;
        eth_reserves = newEthReserves;
        // update k
        k = token_reserves * eth_reserves;
        debugPrint();
        printAccount(msg.sender);
    }

    // Function swapETHForTokens: Swaps ETH for your tokens
    // ETH is sent to contract as msg.value
    // You can change the inputs, or the scope of your function, as needed.
    function swapETHForTokens() external payable {
        /******* TODO: Implement this function *******/
        uint newEthReserves = eth_reserves + msg.value;
        uint newTokenReserves = k / newEthReserves;
        uint amountTokens = token_reserves - newTokenReserves ;
        // check not empty reserves
        require(newTokenReserves > 0, "Not enough token reserves");

        // transfer eth from sender to contract
        // NOTE eth đã được chuyển bằng cách gọi hàm 
        // transfer token from contract to sender
        token.transfer(msg.sender, amountTokens);
        // update reserves
        token_reserves = newTokenReserves;
        eth_reserves = newEthReserves;
        // update k
        k = token_reserves * eth_reserves;
        debugPrint();
        printAccount(msg.sender);
    }
}
