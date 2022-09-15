# Scenario
1. I have an NFT and I need some money.
2. I will put up my nft as collateral for some money.
3. People can see those offers and renegotiate them if they like.
4. Once a negotiation is accepted my NFT stays with the contract.
5. I receive my money for the set period of time allowed.
6. If i fail to pay before the set time, the user can claim the NFT for themselves.
7. If i do pay i have to pay with the interest required too.

# How do i treat loan acceptance
-Done

# How do i traet re negotiations
- No renogatiotions
- Instead the user can change details of the loan

# How do i treat liquidations
1. I can set a maturity date that has an expiry date, after that date the lender can liquidate the nft.



<!-- 
FORGE CREATE FOR DEPLOYMENT
ANVIL
SLITHER
 -->








<!-- BUG BOUNTY THINGY -->


<!-- TEST SCENARIO -->
<!-- Possible bug bounty! -->
1. What if i implement an ierc721 transferfrom on a contract address whose transferfrom just updates the contracts storage variable
IN ESSENCE
How will my contract know that its not a fake erc721.
This can easily be stopped by whitelisting .
