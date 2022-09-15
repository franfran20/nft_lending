// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../../src/LendingContract.sol";
import "../../src/test/MockERC721.sol";

contract TestProposeLoan is Test {
    LendingContract lendingContract;
    MockERC721 mockERC721;
    //
    address accountOne;
    address accountTwo;
    //
    event LoanProposed(
        address indexed lender,
        address indexed borrower,
        uint256 indexed loanId
    );

    function setUp() public {
        // Deploy contracts
        lendingContract = new LendingContract();
        mockERC721 = new MockERC721("TestNft", "TNFT");
        //
        accountOne = vm.addr(1);
        accountTwo = vm.addr(2);
        // mint token for ourselves - TokenId 1
        mockERC721.mintToken(accountOne);
    }

    // TESTING THE CHECK LOAN DETAILS FUNCTION
    function testProposeLoanRevertsIfMaturityDateisZero() external {
        uint256 _maturityDate = 0; //seconds
        uint256 _principal = 1e18;
        uint256 _interest = 2;
        uint256 _tokenId = 1;
        console.log("Nft Address:", address(mockERC721));
        vm.startPrank(accountOne);
        vm.expectRevert(LendingContract__InvalidMaturityDate.selector);
        lendingContract.proposeLoan(
            address(mockERC721),
            _tokenId,
            _maturityDate,
            _principal,
            _interest
        );
        vm.stopPrank();
    }

    function testProposeLoanRevertsIfNftAddressIsZero() external {
        uint256 _maturityDate = 10; //seconds
        uint256 _principal = 1e18;
        uint256 _interest = 2;
        uint256 _tokenId = 1;
        console.log("Nft Address:", address(0));
        vm.startPrank(accountOne);
        vm.expectRevert(LendingContract__InvalidNftAddress.selector);
        lendingContract.proposeLoan(
            address(0),
            _tokenId,
            _maturityDate,
            _principal,
            _interest
        );
        vm.stopPrank();
    }

    function testProposeLoanRevertsIfPrincipalIsZero() external {
        uint256 _maturityDate = 10; //seconds
        uint256 _principal = 0;
        uint256 _interest = 2;
        uint256 _tokenId = 1;
        console.log("Nft Address:", address(mockERC721));
        vm.startPrank(accountOne);
        vm.expectRevert(LendingContract__PrincipalCannotBeZero.selector);
        lendingContract.proposeLoan(
            address(mockERC721),
            _tokenId,
            _maturityDate,
            _principal,
            _interest
        );
        vm.stopPrank();
    }

    // TEST IF THEY OWN THE TOKEN
    function testProposeLoanRevertsIfSenderDoesntOwnToken() external {
        uint256 _maturityDate = 300; // seconds
        uint256 _principal = 1 ether;
        uint256 _interest = 2; // 2%
        uint256 _tokenId = 1;
        //
        vm.startPrank(accountTwo);
        vm.expectRevert(LendingContract__YouDontOwnThisToken.selector);
        lendingContract.proposeLoan(
            address(mockERC721),
            _tokenId,
            _maturityDate,
            _principal,
            _interest
        );
        vm.stopPrank();
    }

    // TEST LOAN ID INCREMENTS
    function testLoanIdIncrements() external {
        uint256 _maturityDate = 300; // seconds
        uint256 _principal = 1 ether;
        uint256 _interest = 2; // 2%
        uint256 _tokenId = 1;
        //
        console.log("LoanId Before proposal:", lendingContract.loanIdCounter());
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
        console.log("LoanId After proposal:", lendingContract.loanIdCounter());

        assertEq(lendingContract.loanIdCounter(), 1);
    }

    // TEST CONTRACT RECEIVES THE NFT
    function testContractReceivesTheNftOnProposal() external {
        uint256 _maturityDate = 300; // seconds
        uint256 _principal = 1 ether;
        uint256 _interest = 2; // 2%
        uint256 _tokenId = 1;

        console.log(
            "proposing loan with",
            address(mockERC721),
            "with token ID of 1"
        );
        vm.startPrank(accountOne);
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
        assertEq(
            IERC721(address(mockERC721)).ownerOf(1),
            address(lendingContract)
        );
    }

    function testLoanExistenceMappingUpdatesOnProposal() external {
        uint256 _maturityDate = 300; // seconds
        uint256 _principal = 1 ether;
        uint256 _interest = 2; // 2%
        uint256 _tokenId = 1;

        vm.startPrank(accountOne);
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
        console.log(lendingContract.loanIdCounter());

        console.log(lendingContract.loanExistence(1));
        assertEq(lendingContract.loanExistence(1), true);
    }

    function testExpectEmitLoanProposed() external {
        uint256 _maturityDate = 300; // seconds
        uint256 _principal = 1 ether;
        uint256 _interest = 2; // 2%
        uint256 _tokenId = 1;

        vm.startPrank(accountOne);
        IERC721(address(mockERC721)).approve(
            address(lendingContract),
            _tokenId
        );

        vm.expectEmit(true, true, true, false);
        emit LoanProposed(
            address(0),
            accountOne,
            lendingContract.loanIdCounter() + 1
        );

        lendingContract.proposeLoan(
            address(mockERC721),
            _tokenId,
            _maturityDate,
            _principal,
            _interest
        );
        vm.stopPrank();
    }

    function testLoansMappingGetsUpdated() external {
        __helpTestLoansMappingWasUpdated();

        (
            uint256 loanId,
            address nftAddress,
            uint256 tokenId,
            uint256 maturityDate,
            uint256 maturityCounter,
            uint256 principal,
            uint256 interest,
            bool accepted,
            address lender,
            address borrower,
            bool paid
        ) = lendingContract.loans(1);

        console.log(accepted);

        assertEq(loanId, 1);
        assertEq(nftAddress, address(mockERC721));
        assertEq(tokenId, 1);
        assertEq(maturityDate, 300);
        assertEq(maturityCounter, 0);
        assertEq(principal, 1 ether);
        assertEq(interest, 2);
        assertEq(accepted, false);
        assertEq(lender, address(0));
        assertEq(borrower, accountOne);
        assertEq(paid, false);
    }

    // HELPER FUNCTION FOR TEST
    function __helpTestLoansMappingWasUpdated() internal {
        uint256 _maturityDate = 300; // seconds
        uint256 _principal = 1 ether;
        uint256 _interest = 2; // 2%
        uint256 _tokenId = 1;

        vm.startPrank(accountOne);
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
    }
}
