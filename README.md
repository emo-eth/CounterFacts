# CounterFacts™

CounterFacts™ are ERC721 tokens that are pointers to data contracts containing the text of a prediction. Did we mention that
the contract might not actually exist?

Upon minting a CounterFact™, the creator supplies the deterministic counterfactual address of this data contract. Anyone can then reveal the text by providing the original data + salt to the reveal function. The data contract will be deployed to the same address, and the token will be updated to display the text the data contract contains.