// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/LendingContract.sol";
import "../../src/test/MockERC721.sol";

contract TestModifyLoan is Test {
    LendingContract lendingContract;
    MockERC721 mockERC721;
    //accounts for testing
    address accountOne;
    address accountTwo;
    //
    uint256 _maturityDate;
    uint256 _principal;
    uint256 _interest;
    uint256 _tokenId;

    //
    event LoanModified(
        uint256 indexed loanId,
        uint256 indexed maturityDate,
        uint256 indexed principal,
        uint256 interest
    );

    function setUp() public {
        // deploy the two contracts
        lendingContract = new LendingContract();
        mockERC721 = new MockERC721("TestNft", "TNFT");
        //
        accountOne = vm.addr(1);
        accountTwo = vm.addr(2);

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

        // at this point the loan exists with an ID of 1. Lets modify it!
    }

    function testModifyLoanRevertsIfLoanDoesNotExist(uint256 loanId) external {
        if (loanId > 1) {
            vm.expectRevert(LendingContract__LoanDoesNotExist.selector);
            lendingContract.modifyLoanDetails(
                loanId,
                _maturityDate + 10,
                _principal + 0.5 ether,
                _interest - 1
            );
        }
    }

    function testModifyLoanRevertsIfModifierIsntCreator() external {
        uint256 loanId = 1;
        vm.startPrank(accountTwo);
        vm.expectRevert(LendingContract__NotOwnerOfLoan.selector);
        lendingContract.modifyLoanDetails(
            loanId,
            _maturityDate + 10,
            _principal + 0.5 ether,
            _interest - 1
        );
        vm.stopPrank();
    }

    function testModifyLoanRevertsIfLoanHasAlreadyBeenAccepted() external {
        uint256 loanId = 1;
        vm.startPrank(accountTwo);

        vm.deal(accountTwo, 1 ether);

        lendingContract.acceptLoan{value: 1 ether}(loanId);

        changePrank(accountTwo);
        // try to modify the loan and expect a revert
        changePrank(accountOne);
        vm.expectRevert(LendingContract_LoanAlreadyAccepted.selector);
        lendingContract.modifyLoanDetails(
            loanId,
            _maturityDate + 10,
            _principal + 0.5 ether,
            _interest - 1
        );
    }

    function testModifyLoanRevertsIfPrincipalOrMaturityDateIsZero() external {
        uint256 loanId = 1;
        vm.startPrank(accountOne);

        uint256 _testMaturityDate = 0;
        uint256 _testPrincipal = 0;
        vm.expectRevert(LendingContract__InvalidMaturityDate.selector);
        lendingContract.modifyLoanDetails(
            loanId,
            _testMaturityDate,
            _principal + 0.5 ether,
            _interest - 1
        );
        //
        vm.expectRevert(LendingContract__PrincipalCannotBeZero.selector);
        lendingContract.modifyLoanDetails(
            loanId,
            _maturityDate + 10,
            _testPrincipal,
            _interest - 1
        );
    }

    function testModifyLoanUpdatesSpecifiedLoanDetails() external {
        uint256 loanId = 1;
        vm.startPrank(accountOne);

        lendingContract.modifyLoanDetails(
            loanId,
            _maturityDate + 10,
            _principal + 0.5 ether,
            _interest - 1
        );

        (
            ,
            ,
            ,
            uint256 maturity,
            ,
            uint256 principal,
            uint256 interest,
            ,
            ,
            ,

        ) = lendingContract.loans(loanId);

        assertEq(maturity, _maturityDate + 10);
        assertEq(principal, _principal + 0.5 ether);
        assertEq(interest, _interest - 1);
    }

    function testExpectEmitLoanModified() external {
        uint256 loanId = 1;
        vm.startPrank(accountOne);

        vm.expectEmit(true, true, true, false);

        emit LoanModified(
            loanId,
            _maturityDate + 10,
            _principal + 0.5 ether,
            _interest - 1
        );

        lendingContract.modifyLoanDetails(
            loanId,
            _maturityDate + 10,
            _principal + 0.5 ether,
            _interest - 1
        );
    }
}
