// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721, IERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title StandardNFT
 * @dev 标准 ERC-721 NFT 合约，包含完整的功能和安全性
 * @author NFT DEX Team
 */
contract StandardNFT is 
    ERC721, 
    ERC721Enumerable, 
    ERC721URIStorage, 
    ERC721Burnable, 
    Ownable, 
    Pausable, 
    ReentrancyGuard 
{
    using Strings for uint256;

    // 状态变量
    uint256 private _tokenIdCounter;
    
    /// @dev 基础 URI，用于构建 tokenURI
    string private _baseTokenUri;
    
    /// @dev 最大供应量限制
    uint256 public maxSupply;
    
    /// @dev 每个地址的最大铸造数量限制
    uint256 public maxMintPerAddress;
    
    /// @dev 铸造价格
    uint256 public mintPrice;
    
    /// @dev 元数据是否已锁定
    bool public metadataLocked;
    
    /// @dev 每个地址已铸造的数量
    mapping(address => uint256) public mintedCount;
    
    // 事件
    event BaseURIUpdated(string newBaseUri);
    event MaxSupplyUpdated(uint256 newMaxSupply);
    event MaxMintPerAddressUpdated(uint256 newMaxMintPerAddress);
    event MintPriceUpdated(uint256 newMintPrice);
    event MetadataLocked();
    event BatchMinted(address indexed to, uint256[] tokenIds);

    // 错误定义
    error ExceedsMaxSupply();
    error ExceedsMaxMintPerAddress();
    error InsufficientPayment();
    error MetadataAlreadyLocked();
    error InvalidTokenId();
    error TransferNotAllowed();

    /**
     * @dev 构造函数
     * @param name NFT 名称
     * @param symbol NFT 符号
     * @param baseTokenUri 基础 URI
     * @param _maxSupply 最大供应量
     * @param _maxMintPerAddress 每个地址最大铸造数量
     * @param _mintPrice 铸造价格
     */
    constructor(
        string memory name,
        string memory symbol,
        string memory baseTokenUri,
        uint256 _maxSupply,
        uint256 _maxMintPerAddress,
        uint256 _mintPrice
    ) ERC721(name, symbol) Ownable(msg.sender) {
        _baseTokenUri = baseTokenUri;
        maxSupply = _maxSupply;
        maxMintPerAddress = _maxMintPerAddress;
        mintPrice = _mintPrice;
    }

    /**
     * @dev 铸造单个 NFT
     * @param to 接收者地址
     * @param uri 元数据 URI
     */
    function mint(address to, string memory uri) 
        public 
        payable 
        whenNotPaused 
        nonReentrant 
    {
        _mintSingle(to, uri);
    }

    /**
     * @dev 批量铸造 NFT
     * @param to 接收者地址
     * @param uris 元数据 URI 数组
     */
    function batchMint(address to, string[] memory uris) 
        public 
        payable 
        whenNotPaused 
        nonReentrant 
    {
        uint256 quantity = uris.length;
        uint256 totalCost = mintPrice * quantity;
        
        if (msg.value < totalCost) {
            revert InsufficientPayment();
        }
        
        if (mintedCount[to] + quantity > maxMintPerAddress) {
            revert ExceedsMaxMintPerAddress();
        }
        
        if (_tokenIdCounter + quantity > maxSupply) {
            revert ExceedsMaxSupply();
        }
        
        uint256[] memory tokenIds = new uint256[](quantity);
        
        for (uint256 i = 0; i < quantity; i++) {
            _tokenIdCounter++;
            uint256 tokenId = _tokenIdCounter;
            tokenIds[i] = tokenId;
            
            _safeMint(to, tokenId);
            _setTokenURI(tokenId, uris[i]);
        }
        
        mintedCount[to] += quantity;
        
        // 退还多余的 ETH
        if (msg.value > totalCost) {
            payable(msg.sender).transfer(msg.value - totalCost);
        }
        
        emit BatchMinted(to, tokenIds);
    }

    /**
     * @dev 内部铸造函数
     * @param to 接收者地址
     * @param uri 元数据 URI
     */
    function _mintSingle(address to, string memory uri) internal {
        if (msg.value < mintPrice) {
            revert InsufficientPayment();
        }
        
        if (mintedCount[to] >= maxMintPerAddress) {
            revert ExceedsMaxMintPerAddress();
        }
        
        if (_tokenIdCounter >= maxSupply) {
            revert ExceedsMaxSupply();
        }
        
        _tokenIdCounter++;
        uint256 tokenId = _tokenIdCounter;
        
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        mintedCount[to]++;
        
        // 退还多余的 ETH
        if (msg.value > mintPrice) {
            payable(msg.sender).transfer(msg.value - mintPrice);
        }
    }

    /**
     * @dev 设置基础 URI（仅所有者）
     * @param newBaseTokenUri 新的基础 URI
     */
    function setBaseURI(string memory newBaseTokenUri) 
        public 
        onlyOwner 
    {
        if (metadataLocked) {
            revert MetadataAlreadyLocked();
        }
        _baseTokenUri = newBaseTokenUri;
        emit BaseURIUpdated(newBaseTokenUri);
    }

    /**
     * @dev 锁定元数据（仅所有者）
     */
    function lockMetadata() public onlyOwner {
        metadataLocked = true;
        emit MetadataLocked();
    }

    /**
     * @dev 设置最大供应量（仅所有者）
     * @param _maxSupply 新的最大供应量
     */
    function setMaxSupply(uint256 _maxSupply) public onlyOwner {
        require(_maxSupply >= _tokenIdCounter, "Cannot decrease below current supply");
        maxSupply = _maxSupply;
        emit MaxSupplyUpdated(_maxSupply);
    }

    /**
     * @dev 设置每个地址最大铸造数量（仅所有者）
     * @param _maxMintPerAddress 新的最大铸造数量
     */
    function setMaxMintPerAddress(uint256 _maxMintPerAddress) public onlyOwner {
        maxMintPerAddress = _maxMintPerAddress;
        emit MaxMintPerAddressUpdated(_maxMintPerAddress);
    }

    /**
     * @dev 设置铸造价格（仅所有者）
     * @param _mintPrice 新的铸造价格
     */
    function setMintPrice(uint256 _mintPrice) public onlyOwner {
        mintPrice = _mintPrice;
        emit MintPriceUpdated(_mintPrice);
    }

    /**
     * @dev 暂停合约（仅所有者）
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev 恢复合约（仅所有者）
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev 预铸造 NFT 到指定地址（仅所有者）
     * @param to 接收者地址
     * @param count 铸造数量
     */
    function premint(address to, uint256 count) public onlyOwner {
        require(count > 0, "Count must be greater than 0");
        require(_tokenIdCounter + count <= maxSupply, "Exceeds max supply");
        
        for (uint256 i = 0; i < count; i++) {
            _tokenIdCounter++;
            uint256 tokenId = _tokenIdCounter;
            _safeMint(to, tokenId);
        }
    }
    
    /**
     * @dev 提取合约余额（仅所有者）
     */
    function withdraw() public onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        address payable recipient = payable(msg.sender);
        recipient.transfer(balance);
    }

    /**
     * @dev 获取当前总供应量
     * @return 当前已铸造的 NFT 数量
     */
    function totalSupply() public view override returns (uint256) {
        return _tokenIdCounter;
    }

    /**
     * @dev 获取基础 URI
     * @return 基础 URI 字符串
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenUri;
    }

    /**
     * @dev 获取 token URI
     * @param tokenId token ID
     * @return token 的完整 URI
     */
    function tokenURI(uint256 tokenId) 
        public 
        view 
        override(ERC721, ERC721URIStorage) 
        returns (string memory) 
    {
        if (!_exists(tokenId)) {
            revert InvalidTokenId();
        }
        
        string memory baseUri = _baseURI();
        string memory uri = super.tokenURI(tokenId);
        
        if (bytes(uri).length > 0) {
            return uri;
        }
        
        return string(abi.encodePacked(baseUri, tokenId.toString()));
    }

    /**
     * @dev 检查 token 是否存在
     * @param tokenId token ID
     * @return 是否存在
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId > 0 && tokenId <= _tokenIdCounter;
    }

    /**
     * @dev 重写 _update 以支持暂停和枚举
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        whenNotPaused
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev 重写 _increaseBalance 以支持枚举
     */
    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }


    /**
     * @dev 重写 supportsInterface 以支持多个接口
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev 重写 transferFrom 以添加自定义逻辑
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override(ERC721, IERC721) {
        // 可以在这里添加自定义转移逻辑
        // 注意：ERC721 的 transferFrom 不返回布尔值，所以不需要检查返回值
        super.transferFrom(from, to, tokenId);
    }

    /**
     * @dev 重写 safeTransferFrom 以添加自定义逻辑
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public override(ERC721, IERC721) {
        // 可以在这里添加自定义转移逻辑
        super.safeTransferFrom(from, to, tokenId, data);
    }
}
