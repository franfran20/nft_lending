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

/// @title A Time Based NFT Lending Contract
/// @author Egbolcuhe Francis
/// @notice A contract that allows for users to use their NFTS as collateral
contract LendingContract is ReentrancyGuard {
    /// @notice Keeps track of the total number of loans so far
    /// @return loanIdCounter returns the current total loans
    uint256 public loanIdCounter;

    /// @notice Contains all the information on a specific loan
    /// @return loanId The loan Id for the specific loan
    /// @return nftAddress the nft contract address being used as collateral
    /// @return tokenId the token Id for the nft contract address
    /// @return maturityDate the time period in seconds that the loan is valid
    /// @return maturityDateCounter the counter that counts down the maturity date as loan gets accepted
    /// @return principal the amount being borrowed by the nft owner
    /// @return interest fixed interest to be paid back to lender
    /// @return accepted keeps track of whether loan has been accepted by a lender
    /// @return lender the address of the lender
    /// @return borrower the address of teh borrower
    /// @return paid if the loan has been paid or not
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

    //keeps track of the loanId to the loan details
    mapping(uint256 => LoanDetails) public loans;

    // keeps track of whether a loanId exists
    mapping(uint256 => bool) public loanExistence;

    /// @notice Emitted when a loan is proposed by a borrower
    /// @param lender the address of the lender
    /// @param borrower the address of the borrower
    /// @param loanId the loan id
    event LoanProposed(
        address indexed lender,
        address indexed borrower,
        uint256 indexed loanId
    );

    /// @notice Emitted when a loan is acccepted by a lender
    /// @param lender the address of the lender
    /// @param borrower the address of the borrower
    /// @param loanId the loan id
    event LoanAccepted(
        address indexed lender,
        address indexed borrower,
        uint256 indexed loanId
    );

    /// @notice Emitted when a loan is modified by the borrower
    /// @param loanId the loan id
    /// @param maturityDate the time period that the loan is valid
    /// @param principal the amount of money the borrower is requesting
    event LoanModified(
        uint256 indexed loanId,
        uint256 indexed maturityDate,
        uint256 indexed principal,
        uint256 interest
    );

    /// @notice Emitted when a loan is repaid by the borrower
    /// @param loanId the loan id
    /// @param amountPaid the total amount paid by the borrower including interest
    event LoanRepaid(uint256 indexed loanId, uint256 indexed amountPaid);

    /// @notice Emitted when a lender claims the nft of the borrower on default
    /// @param loanId the loan id
    /// @param nftAddress the contract address of the nft the lender claimed
    /// @param tokenId the token id of the nft claimed by the lender on default
    event LoanClaimed(
        uint256 indexed loanId,
        address indexed nftAddress,
        uint256 indexed tokenId
    );

    /// @notice allows the borrower to propose a loan using their nft as collateral
    /// @dev The contract takes the nft and holds it until the loan is repaid
    /// @param nftAddress the contract addres of the nft being used as collateral
    /// @param tokenId the token id of the nft contract
    /// @param maturityDate the time allowed fo repayment
    /// @param principal the amount requested by borrower from lender
    /// @param interest the interest the borrower is willing to pay back the lender
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

    /// @notice A lender can choose a loan by its id and accept the terms
    /// @param loanId the loan id for the loan
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

    /// @notice allows the borrower to modify the details of the loan before its accepted
    /// @dev The contract takes the nft and holds it until the loan is repaid
    /// @param loanId the loan id for the loan to be modified
    /// @param maturityDate the time allowed fo repayment
    /// @param principal the amount requested by borrower from lender
    /// @param interest the interest the borrower is willing to pay back the lender
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

    /// @notice allows the borrow to repay loan with the loan id
    /// @param loanId the loan id for the loan
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

    /// @notice A lender can claim the borrowers nft on default
    /// @param loanId the loan id for the loan
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

    /// @notice stores the loan with all its details
    /// @dev updates the loanId mapping with the loan details
    /// @param _loanId the loan id for the loan
    /// @param _nftAddress the contract addres of the nft being used as collateral
    /// @param _tokenId the token id of the nft contract
    /// @param _maturityDate the time allowed fo repayment
    /// @param _principal the amount requested by borrower from lender
    /// @param _interest the interest the borrower is willing to pay back the lender
    /// @param _msgSender the interest the borrower is willing to pay back the lender
    function _initializeLoan(
        uint256 _loanId,
        address _nftAddress,
        uint256 _tokenId,
        uint256 _maturityDate,
        uint256 _principal,
        uint256 _interest,
        address _msgSender
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
            borrower: _msgSender,
            paid: false
        });
    }

    /// @notice checks for invalid loan details parameters
    /// @dev makes sure the nft address isnt zero and the maturity date and principal isnt zero
    /// @param maturityDate the time allowed fo repayment
    /// @param principal the amount requested by borrower from lender
    /// @param nftAddress the interest the borrower is willing to pay back the lender
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

    /// @notice checks if the loan exits
    /// @param loanId the loan id for the loan
    function _checkLoanExistence(uint256 loanId) internal view {
        if (!loanExistence[loanId]) {
            revert LendingContract__LoanDoesNotExist();
        }
    }
}
