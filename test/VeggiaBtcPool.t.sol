// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {SERVER_SIGNER} from "./utils/constants.sol";
import {VeggiaBtcPool} from "src/VeggiaBtcPool.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SignatureHelper} from "./utils/SignatureHelper.sol";

contract WrappedBitcoin is ERC20 {
    constructor() ERC20("Wrapped BTC", "wBTC") {
        _mint(msg.sender, 1_000_000 ether);
    }
}

contract VeggiaBtcPoolTest is Test {
    VeggiaBtcPool public veggiaBtcPool;
    WrappedBitcoin public wBTC;

    function setUp() public {
        // deploy the Wrapped BTC contract
        wBTC = new WrappedBitcoin();

        // deploy the VeggiaBtcPool contract
        address rewardSigner = vm.addr(uint256(SERVER_SIGNER));
        veggiaBtcPool = new VeggiaBtcPool(wBTC, rewardSigner);

        // approve the VeggiaBtcPool to spend Wrapped BTC
        wBTC.approve(address(veggiaBtcPool), 1_000_000 ether);
    }

    function test_fuzz_withdrawRewards(string memory random, uint256 amount, address user) public {
        amount = bound(amount, 0, 1_000_000 ether);

        vm.assume(user != address(0));
        vm.assume(user.code.length == 0);
        (address rewardSigner, uint256 signer) = makeAddrAndKey(random);

        assertEq(wBTC.balanceOf(address(veggiaBtcPool)), 0);

        veggiaBtcPool.deposit(wBTC.balanceOf(address(this)));
        veggiaBtcPool.setRewardSigner(rewardSigner);

        console.log("rewardSigner: %x", rewardSigner);

        assertEq(wBTC.balanceOf(address(veggiaBtcPool)), 1_000_000 ether);
        assertEq(wBTC.balanceOf(user), 0);
        assertEq(veggiaBtcPool.rewardSigner(), rewardSigner);

        VeggiaBtcPool.WithdrawRequest memory req = VeggiaBtcPool.WithdrawRequest(user, amount);
        bytes memory signature = SignatureHelper.signBtcRewardAs(veggiaBtcPool, bytes32(signer), user, amount);

        vm.expectEmit(true, true, true, true);
        emit VeggiaBtcPool.RewardWithdrawn(req.to, req.amount, signature);
        vm.prank(user);
        veggiaBtcPool.withdrawRewards(req, signature);

        assertEq(wBTC.balanceOf(address(veggiaBtcPool)), 1_000_000 ether - amount);
        assertEq(wBTC.balanceOf(user), amount);
    }
}
