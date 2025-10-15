// StandardNFT 合约 ABI
export const StandardNFT_ABI = [
  // 构造函数
  "constructor(string memory name, string memory symbol, string memory baseURI, uint256 maxSupply, uint256 maxMintPerAddress, uint256 mintPrice)",
  
  // ERC721 标准方法
  "function name() public view returns (string memory)",
  "function symbol() public view returns (string memory)",
  "function totalSupply() public view returns (uint256)",
  "function balanceOf(address owner) public view returns (uint256)",
  "function ownerOf(uint256 tokenId) public view returns (address)",
  "function tokenURI(uint256 tokenId) public view returns (string memory)",
  "function approve(address to, uint256 tokenId) public",
  "function getApproved(uint256 tokenId) public view returns (address)",
  "function setApprovalForAll(address operator, bool approved) public",
  "function isApprovedForAll(address owner, address operator) public view returns (bool)",
  "function transferFrom(address from, address to, uint256 tokenId) public",
  "function safeTransferFrom(address from, address to, uint256 tokenId) public",
  "function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public",
  
  // 自定义方法
  "function mint(address to, string memory uri) public payable",
  "function batchMint(address to, string[] memory uris) public payable",
  "function premint(address to, uint256 count) public",
  "function burn(uint256 tokenId) public",
  "function pause() public",
  "function unpause() public",
  "function withdraw() public",
  "function setBaseURI(string memory newBaseURI) public",
  "function setMintPrice(uint256 newPrice) public",
  "function setMaxMintPerAddress(uint256 newMax) public",
  "function mintPrice() public view returns (uint256)",
  "function maxSupply() public view returns (uint256)",
  "function maxMintPerAddress() public view returns (uint256)",
  
  // 事件
  "event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)",
  "event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId)",
  "event ApprovalForAll(address indexed owner, address indexed operator, bool approved)",
  "event Minted(address indexed to, uint256 tokenId, uint256 price)",
  "event BatchMinted(address indexed to, uint256[] tokenIds)",
  "event Burned(uint256 indexed tokenId)",
  "event Paused(address account)",
  "event Unpaused(address account)",
];

// Pair 合约 ABI
export const Pair_ABI = [
  // 构造函数
  "constructor(address _nftContract)",
  
  // 核心交易方法
  "function buyNFT(uint256 maxPrice) public payable",
  "function sellNFT(uint256 tokenId, uint256 minPrice) public",
  "function addLiquidity(uint256[] calldata nftTokenIds) public payable",
  "function removeLiquidity(uint256 lpTokenAmount, uint256[] calldata nftTokenIds) public",
  "function addInitialLiquidity(uint256[] calldata nftTokenIds) external payable",
  
  // 价格查询方法
  "function getCurrentPrice() public view returns (uint256)",
  "function getSellPrice() public view returns (uint256)",
  "function getBuyQuote() public view returns (uint256 totalCost, uint256 fee)",
  "function getPoolReserves() external view returns (uint256 ethReserve, uint256 nftReserveCount)",
  
  // 交易历史方法
  "function getTradeHistory() external view returns (tuple(address trader, bool isBuy, uint256 price, uint256 timestamp)[] memory)",
  "function getRecentTrades(uint256 count) external view returns (tuple(address trader, bool isBuy, uint256 price, uint256 timestamp)[] memory)",
  "function getAccumulatedFees() external view returns (uint256)",
  
  // 管理方法
  "function pause() public",
  "function unpause() public",
  "function withdrawFees() public",
  "function transferOwnership(address newOwner) public",
  
  // 事件
  "event NFTBought(address indexed buyer, uint256 tokenId, uint256 price, uint256 fee)",
  "event NFTSold(address indexed seller, uint256 tokenId, uint256 price, uint256 fee)",
  "event PriceUpdated(uint256 newPrice, uint256 ethReserve, uint256 nftReserve)",
  "event LiquidityAdded(uint256 ethAmount, uint256 nftCount)",
  "event LPTokensMinted(address indexed to, uint256 amount)",
  "event LPTokensBurned(address indexed from, uint256 amount)",
  "event FeesAccumulated(uint256 feeAmount, uint256 totalAccumulatedFees)",
  "event FeesWithdrawn(address indexed owner, uint256 amount)",
];

// PairFactory 合约 ABI
export const PairFactory_ABI = [
  // 构造函数
  "constructor()",
  
  // 池子管理方法
  "function createPool(address nftContract) external returns (address poolAddress)",
  "function getPoolAddress(address nftContract) external view returns (address poolAddress)",
  
  // 管理方法
  "function owner() public view returns (address)",
  "function transferOwnership(address newOwner) public",
  "function renounceOwnership() public",
  
  // 事件
  "event PoolCreated(address indexed poolAddress, address indexed nftContract)",
  "event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)",
];

// LPToken 合约 ABI
export const LPToken_ABI = [
  // ERC20 标准方法
  "function name() public view returns (string memory)",
  "function symbol() public view returns (string memory)",
  "function decimals() public view returns (uint8)",
  "function totalSupply() public view returns (uint256)",
  "function balanceOf(address account) public view returns (uint256)",
  "function transfer(address to, uint256 amount) public returns (bool)",
  "function allowance(address owner, address spender) public view returns (uint256)",
  "function approve(address spender, uint256 amount) public returns (bool)",
  "function transferFrom(address from, address to, uint256 amount) public returns (bool)",
  
  // 自定义方法
  "function mint(address to, uint256 amount) external",
  "function burn(address from, uint256 amount) external",
  "function batchTransfer(address from, address to, uint256 amount) external",
  
  // 事件
  "event Transfer(address indexed from, address indexed to, uint256 value)",
  "event Approval(address indexed owner, address indexed spender, uint256 value)",
];
