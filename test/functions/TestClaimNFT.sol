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

    event LoanClaimed(
        uint256 indexed loanId,
        address indexed nftAddress,
        uint256 indexed tokenId
    );

    function setUp() public {
        // deploy the two contracts
        lendingContract = new LendingContract();
        mockERC721 = new MockERC721("TestNft", "TNFT");
        //two addresses for testing
        accountOne = vm.addr(1);
        accountTwo = vm.addr(2);
        loanId = 1;

        // mint a token to account one
        mockERC721.mintToken(accountOne);

        // make account one make a proposal
        _maturityDate = 300; // 300 seconds
        _principal = 1e18; // how much borrower is borrowng ~ 1ETH
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

        // at this point the loan exists with an ID of 1. Lets acccept it!
        vm.startPrank(accountTwo);
        deal(accountTwo, 1 ether);
        lendingContract.acceptLoan{value: 1 ether}(loanId);
        vm.stopPrank();

        //skip time after loan deadline and assume borrower hasn't paid!
        skip(301);
    }

    function testClaimNftRevertsIfLoanDoesNotExist(uint256 _loanId) external {
        vm.startPrank(accountTwo);
        if (_loanId > 1) {
            vm.expectRevert(LendingContract__LoanDoesNotExist.selector);
            lendingContract.claimNFTOnDefault(_loanId);
        }
    }

    function testClaimNftRevertsIfTheLoanHasAlreadyBeenPaid() external {
        vm.startPrank(accountOne);
        // to repay you need to pay with the interest
        // interest - 5% of 1ETH = 0.05 ether
        deal(accountOne, 1.05 ether);
        lendingContract.repayLoan{value: 1.05 ether}(loanId);
        // trying to repay again would fail
        // LendingContract__LoanAlreadyPaid
        changePrank(accountTwo);
        vm.expectRevert(LendingContract__LoanAlreadyPaid.selector);
        lendingContract.claimNFTOnDefault(loanId);
        vm.stopPrank();
    }

    function testClaimNftRevertsIfTheLoanIsntDue() external {
        vm.startPrank(accountTwo);
        rewind(100); //go bak 100secs
        vm.expectRevert(LendingContract__LoanNotDueYet.selector);
        lendingContract.claimNFTOnDefault(loanId);
    }

    function testClaimNftTransfersTheTokenToLenderOnDefault() external {
        vm.startPrank(accountTwo);
        lendingContract.claimNFTOnDefault(loanId);

        address ownerOfToken = MockERC721(address(mockERC721)).ownerOf(
            _tokenId
        );
        assertEq(accountTwo, ownerOfToken);
    }

    function testClaimNftUpdatesLoanPaidDetails() external {
        vm.startPrank(accountTwo);
        lendingContract.claimNFTOnDefault(loanId);

        (, , , , , , , , , , bool paid) = lendingContract.loans(loanId);

        assertEq(paid, true);
    }

    function testExpectEmitLoanClaimed() external {
        vm.startPrank(accountTwo);
        vm.expectEmit(true, true, true, false);

        emit LoanClaimed(loanId, address(mockERC721), _tokenId);

        lendingContract.claimNFTOnDefault(loanId);
    }
}
