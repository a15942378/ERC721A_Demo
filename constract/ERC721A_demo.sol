// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract ERC721ADemo is ERC721A, Ownable {

    using Strings for uint256;

	// Constants
	// ?
	uint256 public MINT_PRICE = 0.1 ether;
	uint256 public constant MAX_MINT_SUPPLY = 8000;
    uint256 public MAX_ONCE_MINT_AMOUNT = 5;
    uint256 public MAX_USER_MINT_AMOUNT = 5;

	// Sale Status
	bool public isPublicSaleActive = false;
	bool public isPresaleActive = false;

    // 盲盒開關
    bool public isRevealed = true;

	// White List
	bytes32 public merkleRoot;

	// IPFS
    string private baseURI;
    string public notRevealedUri;
    string public baseExtension = ".json";

    mapping(uint256 => string) private _tokenURIs;

	constructor() ERC721A("ERC721ADemo", "DEMO") {
		
	}

	modifier mintRule(uint256 quantity) {
		// totalSupply 是被燒毀的NFT數量?
		require(
            _totalMinted() + quantity <= MAX_MINT_SUPPLY,
            "Sale would exceed max supply"
        );
		
		// balanceOf, _numberMinted 是一樣的
		require(
            _numberMinted(msg.sender) + quantity <= MAX_USER_MINT_AMOUNT,
            "Sale would exceed max balance"
        );

        require(
            quantity * MINT_PRICE <= msg.value,
            "Not enough ether sent"
        );

        require(
            quantity <= MAX_ONCE_MINT_AMOUNT,
            "Can only mint 5 tokens at a time"
        );

		// 標示哪裡會呼叫函式
		_;
	}

	function preMintNFT(uint256 quantity, bytes32[] calldata proof) public payable mintRule(quantity) {
		require(isPresaleActive, "Presale is not active");
		require(
            _isAllowlisted(msg.sender, proof, merkleRoot),
            "Not on allow list"
        );

	   _mint(quantity);
	}

	function publicMintNFT(uint256 quantity) public payable mintRule(quantity) {
        // 檢查條件如果用成修飾符 會有順序問題
        require(
            isPublicSaleActive,
            "Sale must be active to Mint"
        );

		_mint(quantity);
	}

    // TODO: 要注意的地方
	function ownerMintNFT(uint256 quantity) external onlyOwner {
        require(
            _totalMinted() + quantity <= MAX_MINT_SUPPLY,
            "Max mint supply reached"
        );

        _safeMint(msg.sender, quantity);
	}

	function _mint(uint256 quantity) internal {
		// _safeMint's second argument now takes in a quantity, not a tokenId.
		_safeMint(msg.sender, quantity);
	}

	function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (isRevealed == true) {
            return notRevealedUri;
        }

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        if (bytes(base).length == 0) {
            return _tokenURI;
        }

        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(base, tokenId.toString(), baseExtension));
    }

	function togglePresaleStatus() external onlyOwner {
        isPresaleActive = !isPresaleActive;
    }

    function togglePublicSaleStatus() external onlyOwner {
        isPublicSaleActive = !isPublicSaleActive;
    }

	function setMerkleRoot(bytes32 _root) external onlyOwner {
        merkleRoot = _root;
    }

    function setNotRevealedURI(string memory _notRevealedURI) public onlyOwner {
        notRevealedUri = _notRevealedURI;
    }
	
    function setMintPrice(uint256 _mintPrice) public onlyOwner {
        MINT_PRICE = _mintPrice;
    }

    function setMaxBalance(uint256 _maxBalance) public onlyOwner {
        MAX_USER_MINT_AMOUNT = _maxBalance;
    }

    function setMaxMint(uint256 _maxMint) public onlyOwner {
        MAX_USER_MINT_AMOUNT = _maxMint;
    }

	function setBaseURI(string memory uri) external onlyOwner {
        baseURI = uri;
    }

    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
    }


    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

	function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        Address.sendValue(payable(owner()), balance);
    }

	// 轉給特定的人
	// function withdraw(address to) public onlyOwner {
    //     uint256 balance = address(this).balance;
    //     payable(to).transfer(balance);
    // }

	function _leaf(address _account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_account));
    }

	function _isAllowlisted(
        address _account,
        bytes32[] calldata _proof,
        bytes32 _root
    ) internal pure returns (bool) {
        return MerkleProof.verify(_proof, _root, _leaf(_account));
    }
}