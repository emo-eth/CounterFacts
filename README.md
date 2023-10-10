# Counterfacts™

Counterfacts™ are ERC721 tokens that are pointers to data contracts containing the text of a prediction. Did we mention that
the contract might not actually exist?

Upon minting a Counterfact™, the creator supplies the deterministic counterfactual address of this data contract. Anyone can then reveal the text by providing the original data + salt to the reveal function. The data contract will be deployed to the same address, and the token will be updated to display the text the data contract contains.

# Minting via the Forge CLI

-   Copy the contents of `sample.env` to a new file named `.env` and update accordingly
-   Verify the script runs correctly with `forge script Mint -vvvv` for verbose output
-   If minting with a private key: run `forge script Mint --broadcast`
-   If minting with a Ledger: run `forge script Mint --broadcast --ledger`
