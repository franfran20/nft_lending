// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/LendingContract.sol";
import "../../src/test/MockERC721.sol";

contract TestAcceptLoan is Test {
    LendingContract lendingContract;
    MockERC721 mockERC721;
    //
    address accountOne;
    address accountTwo;
    //
    uint256 _maturityDate;
    uint256 _principal;
    uint256 _interest;
    uint256 _tokenId;

    event LoanAccepted(
        address indexed lender,
        address indexed borrower,
        uint256 indexed loanId
    );

    function setUp() public {
        // deploy the two contracts
        lendingContract = new LendingContract();
        mockERC721 = new MockERC721("TestNft", "TNFT");
        //two accounts for testing
        accountOne = vm.addr(1);
        accountTwo = vm.addr(2);

        // mint a token to account one
        mockERC721.mintToken(accountOne);

        // make account one make a proposal
        _maturityDate = 300; // 300 seconds
        _principal = 1e18; // how much accountOne Wants To Borrow ~ 1ETH
        _interest = 5; // 5% interest on loan
        _tokenId = 1;

        vm.startPrank(accountOne);
        // approve the erc721 contract
        IERC721(address(mockERC721)).approve(
            address(lendingContract),
            _tokenId
        );
        // propose Loan
        lendingContract.proposeLoan(
            address(mockERC721),
            _tokenId,
            _maturityDate,
            _principal,
            _interest
        );
        vm.stopPrank();

        // at this point the loan exists with an ID of 1. Lets modify it!
    }

    function testAcceptLoanRevertsIfLoanDoesNotExist(uint256 loanId) external {
        if (loanId > 1) {
            vm.expectRevert(LendingContract__LoanDoesNotExist.selector);
            lendingContract.acceptLoan{value: 1 ether}(loanId);
        }
    }

    function testAcceptLoanRevertsIfLoanIsAlreadyAccepted() external {
        uint256 loanId = 1;
        lendingContract.acceptLoan{value: 1 ether}(loanId);
        vm.expectRevert(LendingContract_LoanAlreadyAccepted.selector);
        lendingContract.acceptLoan{value: 1 ether}(loanId);
    }

    function testAcceptLoanRevertsIfPrincipalIsNotMet(uint256 fundAmount)
        external
    {
        uint256 loanId = 1;

        (, , , , , uint256 principal, , , , , ) = lendingContract.loans(loanId);
        vm.deal(accountTwo, 10 ether);
        vm.assume(fundAmount <= 10 ether);

        vm.startPrank(accountTwo);
        if (fundAmount < principal) {
            vm.expectRevert(LendingContract__InsufficientPrincipal.selector);
            lendingContract.acceptLoan{value: fundAmount}(loanId);
        }
    }

    function testBorrowerRecivesPrincipal() external {
        uint256 loanId = 1;
        vm.deal(accountTwo, 1 ether);
        uint256 preAcct1Balance = accountOne.balance;
        console.log("Pre-Account 1 balance: ", preAcct1Balance);
        vm.startPrank(accountTwo);
        lendingContract.acceptLoan{value: 1 ether}(loanId);

        console.log("Account 1 balance", accountOne.balance);
        assertEq(preAcct1Balance + 1 ether, accountOne.balance);
    }

    function testLoanDetailsWereUpdatedOnAcceptance() external {
        uint256 loanId = 1;
        vm.deal(accountTwo, 1 ether);
        vm.startPrank(accountTwo);
        lendingContract.acceptLoan{value: 1 ether}(loanId);

        (
            ,
            ,
            ,
            uint256 maturityDate,
            uint256 maturityDateCounter,
            ,
            ,
            bool accepted,
            address lender,
            ,

        ) = lendingContract.loans(loanId);

        assertEq(maturityDateCounter, maturityDate + block.timestamp);
        assertEq(lender, accountTwo);
        assertEq(accepted, true);
    }

    function testExpectEmitLoanAcceptedEvent() external {
        uint256 loanId = 1;
        vm.deal(accountTwo, 1 ether);
        vm.startPrank(accountTwo);

        (, , , , , , , , , address borrower, ) = lendingContract.loans(loanId);

        vm.expectEmit(true, true, true, false);

        emit LoanAccepted(accountTwo, borrower, loanId);
        lendingContract.acceptLoan{value: 1 ether}(loanId);
    }
}
