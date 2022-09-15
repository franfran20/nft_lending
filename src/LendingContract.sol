// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

error LendingContract__InvalidMaturityDate();
error LendingContract__PrincipalCannotBeZero();
error LendingContract_LoanAlreadyAccepted();
error LendingContract__YouDontOwnThisToken();
error LendingContract__InsufficientPrincipal();
error LendingContract__FailedToSendAsset();
error LendingContract__InvalidNftAddress();
error LendingContract__NotOwnerOfLoan();
error LendingContract__InsufficientRepayAmount();
error LendingContract__LoanDoesNotExist();
error LendingContract__LoanAlreadyPaid();
error LendingContract__LoanNotDueYet();

error LendingContract_LoanHasntBeenAccepted();

contract LendingContract is ReentrancyGuard {
    uint256 public loanIdCounter;

    struct LoanDetails {
        uint256 loanId;
        address nftAddress;
        uint256 tokenId;
        uint256 maturityDate;
        uint256 maturityDateCounter;
        uint256 principal;
        uint256 interest;
        bool accepted;
        address lender;
        address borrower;
        bool paid;
    }

    mapping(uint256 => LoanDetails) public loans;
    mapping(uint256 => bool) public loanExistence;

    event LoanProposed(
        address indexed lender,
        address indexed borrower,
        uint256 indexed loanId
    );
    event LoanAccepted(
        address indexed lender,
        address indexed borrower,
        uint256 indexed loanId
    );
    event LoanModified(
        uint256 indexed loanId,
        uint256 indexed maturityDate,
        uint256 indexed principal,
        uint256 interest
    );
    event LoanRepaid(uint256 indexed loanId, uint256 indexed amountPaid);
    event LoanClaimed(
        uint256 indexed loanId,
        address indexed nftAddress,
        uint256 indexed tokenId
    );

    function proposeLoan(
        address nftAddress,
        uint256 tokenId,
        uint256 maturityDate,
        uint256 principal,
        uint256 interest
    ) public nonReentrant {
        // check if they own nft?
        // make some require checks
        _checkLoanDetails(maturityDate, principal, nftAddress);
        if (IERC721(nftAddress).ownerOf(tokenId) != msg.sender) {
            revert LendingContract__YouDontOwnThisToken();
        }

        // store in contract
        loanIdCounter++;
        _initializeLoan(
            loanIdCounter,
            nftAddress,
            tokenId,
            maturityDate,
            principal,
            interest,
            msg.sender
        );

        // take the nft from the borrower
        IERC721(nftAddress).transferFrom(msg.sender, address(this), tokenId);
        loanExistence[loanIdCounter] = true;

        emit LoanProposed(address(0), msg.sender, loanIdCounter);
    }

    function acceptLoan(uint256 loanId) public payable nonReentrant {
        // also check if loan exists
        _checkLoanExistence(loanId);
        LoanDetails memory loanDetails = loans[loanId];
        if (loanDetails.accepted) {
            revert LendingContract_LoanAlreadyAccepted();
        }
        // transfer asset to borrower
        if (msg.value < loanDetails.principal) {
            revert LendingContract__InsufficientPrincipal();
        }
        (bool success, ) = loanDetails.borrower.call{
            value: loanDetails.principal
        }("");
        if (!success) {
            revert LendingContract__FailedToSendAsset();
        }

        loanDetails.lender = msg.sender;
        loanDetails.accepted = true;
        // the maturity date should start its count
        loanDetails.maturityDateCounter =
            loanDetails.maturityDate +
            block.timestamp;

        // save the loan to storage
        loans[loanId] = loanDetails;

        emit LoanAccepted(msg.sender, loanDetails.borrower, loanId);
    }

    // change loan details
    function modifyLoanDetails(
        uint256 loanId,
        uint256 maturityDate,
        uint256 principal,
        uint256 interest
    ) public {
        // check if loan exists
        _checkLoanExistence(loanId);

        LoanDetails memory loanDetails = loans[loanId];
        if (msg.sender != loanDetails.borrower) {
            revert LendingContract__NotOwnerOfLoan();
        }
        if (loanDetails.accepted) {
            revert LendingContract_LoanAlreadyAccepted();
        }

        _checkLoanDetails(maturityDate, principal, loanDetails.nftAddress);

        loanDetails.maturityDate = maturityDate;
        loanDetails.interest = interest;
        loanDetails.principal = principal;

        loans[loanId] = loanDetails;

        emit LoanModified(loanId, maturityDate, principal, interest);
    }

    // repay loan
    // anyone can repay the loan on behalf of someone else

    function repayLoan(uint256 loanId) public payable nonReentrant {
        // check if loan exists
        _checkLoanExistence(loanId);

        LoanDetails memory loanDetails = loans[loanId];
        // accepted?
        if (!loanDetails.accepted) {
            revert LendingContract_LoanHasntBeenAccepted();
        }
        // check if loan has been repaid
        if (loanDetails.paid) {
            revert LendingContract__LoanAlreadyPaid();
        }

        // transfer the principl plus interest back to lender
        uint256 principal = loanDetails.principal;
        uint256 interest = (loanDetails.interest * principal) / 100;

        uint256 totalAmount = principal + interest;
        if (msg.value < totalAmount) {
            revert LendingContract__InsufficientRepayAmount();
        }
        (bool success, ) = loanDetails.lender.call{value: totalAmount}("");
        if (!success) {
            revert LendingContract__FailedToSendAsset();
        }
        // claim your nft back
        IERC721(loanDetails.nftAddress).transferFrom(
            address(this),
            loanDetails.borrower,
            loanDetails.tokenId
        );
        loanDetails.paid = true;

        loans[loanId] = loanDetails;

        emit LoanRepaid(loanId, totalAmount);
    }

    // claimNFT on default

    function claimNFTOnDefault(uint256 loanId) public nonReentrant {
        LoanDetails memory loanDetails = loans[loanId];
        // check if loan has been repaid
        // check if loan exists
        _checkLoanExistence(loanId);
        if (loanDetails.paid) {
            revert LendingContract__LoanAlreadyPaid();
        }

        // is loan due?
        if (block.timestamp < loanDetails.maturityDateCounter) {
            revert LendingContract__LoanNotDueYet();
        }
        // transfer the nft to lender and set the loan as paid
        IERC721(loanDetails.nftAddress).transferFrom(
            address(this),
            loanDetails.lender,
            loanDetails.tokenId
        );

        loanDetails.paid = true;

        loans[loanId] = loanDetails;

        emit LoanClaimed(loanId, loanDetails.nftAddress, loanDetails.tokenId);
    }

    // INTERNAL FUNCTIONS

    function _initializeLoan(
        uint256 _loanId,
        address _nftAddress,
        uint256 _tokenId,
        uint256 _maturityDate,
        uint256 _principal,
        uint256 _interest,
        address msgSender
    ) internal {
        loans[_loanId] = LoanDetails({
            loanId: _loanId,
            nftAddress: _nftAddress,
            tokenId: _tokenId,
            maturityDate: _maturityDate,
            maturityDateCounter: 0,
            principal: _principal,
            interest: _interest,
            accepted: false,
            lender: address(0),
            borrower: msgSender,
            paid: false
        });
    }

    function _checkLoanDetails(
        uint256 maturityDate,
        uint256 principal,
        address nftAddress
    ) internal pure {
        if (nftAddress == address(0)) {
            revert LendingContract__InvalidNftAddress();
        }
        if (maturityDate == 0) {
            revert LendingContract__InvalidMaturityDate();
        } else if (principal == 0) {
            revert LendingContract__PrincipalCannotBeZero();
        }
    }

    function _checkLoanExistence(uint256 loanId) internal view {
        if (!loanExistence[loanId]) {
            revert LendingContract__LoanDoesNotExist();
        }
    }

    // GETTER FUNCTIONS - TO BE ADDED
}
