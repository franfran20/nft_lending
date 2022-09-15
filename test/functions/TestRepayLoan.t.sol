// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/LendingContract.sol";
import "../../src/test/MockERC721.sol";

contract TestRepayLoan is Test {
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
    uint256 loanId;

    event LoanRepaid(uint256 indexed loanId, uint256 indexed amountPaid);

    function setUp() public {
        // deploy the two contracts
        lendingContract = new LendingContract();
        mockERC721 = new MockERC721("TestNft", "TNFT");
        //
        accountOne = vm.addr(1);
        accountTwo = vm.addr(2);
        loanId = 1;

        // mint a token to account one
        mockERC721.mintToken(accountOne);

        // make account one make a proposal
        _maturityDate = 300; // 300 seconds
        _principal = 1e18; // how much borrower wants ~ 1ETH
        _interest = 5; // 5% interest on loan
        _tokenId = 1;

        vm.startPrank(accountOne);
        // approve the erc721 contract
        IERC721(address(mockERC721)).approve(
            address(lendingContract),
            _tokenId
        );

        lendingContract.proposeLoan(
            address(mockERC721),
            _tokenId,
            _maturityDate,
            _principal,
            _interest
        );
        vm.stopPrank();

        // at this point the loan exists with an ID of 1. Lets acccept it
        vm.startPrank(accountTwo);
        deal(accountTwo, 1 ether);
        lendingContract.acceptLoan{value: 1 ether}(loanId);
        vm.stopPrank();
        // now we want to repay loan before the set time!
    }

    function testRepayLoanRevertsIfLoanDoesNotExist() external {
        // paying with high amount for now
        vm.startPrank(accountOne);
        vm.expectRevert(LendingContract__LoanDoesNotExist.selector);
        lendingContract.repayLoan(loanId + 1);
    }

    function testRepayLoanRevertsIfTheLoanHasntBeenAccepted() external {
        uint256 _tokenIdTwo = 2;
        vm.startPrank(accountOne);

        // mint a token to account one
        mockERC721.mintToken(accountOne);

        IERC721(address(mockERC721)).approve(
            address(lendingContract),
            _tokenIdTwo
        );

        lendingContract.proposeLoan(
            address(mockERC721),
            _tokenIdTwo,
            _maturityDate,
            _principal,
            _interest
        );
        deal(accountOne, 1.05 ether);

        vm.expectRevert(LendingContract_LoanHasntBeenAccepted.selector);
        lendingContract.repayLoan{value: 1.05 ether}(loanId + 1);
    }

    function testRepayLoanRevertsIfTheLoanIsAlreadyPaid() external {
        vm.startPrank(accountOne);
        // to repay you need to pay with the interest
        // interest of 5% on 1ETH meaning 0.05 ether
        deal(accountOne, 1.05 ether);
        lendingContract.repayLoan{value: 1.05 ether}(loanId);
        // trying to repay again would fail
        deal(accountOne, 1.05 ether);
        vm.expectRevert(LendingContract__LoanAlreadyPaid.selector);
        lendingContract.repayLoan{value: 1.05 ether}(loanId);
        vm.stopPrank();
    }

    function testRepayLoanRevertsIfInterestIsNotIncluded(uint256 amount)
        external
    {
        vm.startPrank(accountOne);
        // to repay you need to pay with the interest
        // interest of 5% on 1ETH meaning 0.05 ether
        deal(accountOne, 10 ether);

        uint256 preAccountTwoBalance = accountTwo.balance;
        vm.assume(amount < 10 ether);

        // get the totalAmount
        uint256 principal = 1 ether;
        uint256 interest = 0.05 ether;
        uint256 totalAmount = principal + interest;

        if (amount < totalAmount) {
            vm.expectRevert(LendingContract__InsufficientRepayAmount.selector);
            lendingContract.repayLoan{value: amount}(loanId);
        } else {
            lendingContract.repayLoan{value: amount}(loanId);
            assertEq(accountTwo.balance, preAccountTwoBalance + 1.05 ether);
        }
    }

    function testRepayLoanTransfersTheTokenBackToTheBorrower() external {
        vm.startPrank(accountOne);
        deal(accountOne, 1.05 ether);
        lendingContract.repayLoan{value: 1.05 ether}(loanId);

        // did nft get transferred back to owner?
        address ownerOfToken = MockERC721(address(mockERC721)).ownerOf(
            _tokenId
        );
        assertEq(ownerOfToken, accountOne);
    }

    function testRepayLoanUpdatedLoanPaidDetail() external {
        vm.startPrank(accountOne);
        deal(accountOne, 1.05 ether);
        lendingContract.repayLoan{value: 1.05 ether}(loanId);

        (, , , , , , , , , , bool paid) = lendingContract.loans(loanId);
        assertEq(paid, true);
    }

    function testExpectEmitLoanRepaid() external {
        vm.startPrank(accountOne);
        deal(accountOne, 1.05 ether);

        uint256 principal = 1 ether;
        uint256 interest = 0.05 ether;
        uint256 totalAmount = principal + interest;

        // event LoanRepaid(uint256 indexed loanId, uint256 indexed amountPaid);
        vm.expectEmit(true, true, false, false);

        emit LoanRepaid(loanId, totalAmount);
        lendingContract.repayLoan{value: 1.05 ether}(loanId);
    }
}
